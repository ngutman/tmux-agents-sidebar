#!/usr/bin/env python3
import argparse
import os
import re
import select
import signal
import subprocess
import sys
import termios
import time
import tty
from dataclasses import dataclass
from typing import List, Optional, Tuple

INPUT_POLL_INTERVAL = 0.03
SNAPSHOT_INTERVAL = 0.15

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
FG_CYAN = "\033[36m"
FG_GREEN = "\033[32m"
FG_YELLOW = "\033[38;5;226m"
FG_RED = "\033[31m"
FG_GRAY = "\033[90m"
FG_MAGENTA = "\033[35m"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
CLEAR_SCREEN = "\033[2J"
HOME = "\033[H"
CLEAR_LINE = "\033[2K"
ENABLE_MOUSE = "\033[?1000h\033[?1006h"
DISABLE_MOUSE = "\033[?1000l\033[?1006l"
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


class SidebarError(RuntimeError):
    pass


@dataclass(frozen=True)
class Entry:
    label: str
    pane_id: str
    window_id: str
    window_name: str
    kind: str
    provider: str
    status: str
    status_text: str
    folder: str
    branch: str
    command: str
    active: bool


@dataclass(frozen=True)
class SidebarState:
    mode: str
    active_name: str
    last_active_name: str
    sidebar_pane: str
    focus_pane: str
    epoch: int
    width: int
    height: int
    entries: List[Entry]


class TerminalController:
    def __init__(self) -> None:
        self.fd = sys.stdin.fileno()
        self.original = termios.tcgetattr(self.fd)

    def __enter__(self) -> "TerminalController":
        tty.setcbreak(self.fd)
        sys.stdout.write(HIDE_CURSOR + ENABLE_MOUSE + HOME)
        sys.stdout.flush()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        termios.tcsetattr(self.fd, termios.TCSADRAIN, self.original)
        sys.stdout.write(DISABLE_MOUSE + SHOW_CURSOR + RESET + "\n")
        sys.stdout.flush()


class SidebarApp:
    def __init__(self, session: str, controller: str) -> None:
        self.session = session
        self.controller = controller
        self.state: Optional[SidebarState] = None
        self.selected_index = 0
        self.last_lines: List[str] = []
        self.redraw_full = True
        self.force_snapshot = True
        self.last_snapshot_at = 0.0
        self.message = ""
        self.message_until = 0.0
        self.last_repair_attempt_at = 0.0
        self.selection_label_hint: Optional[str] = None

    def run_controller(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([self.controller, *args], capture_output=True, text=True)

    def set_message(self, message: str, seconds: float = 1.5) -> None:
        self.message = message
        self.message_until = time.time() + seconds

    def clear_message_if_expired(self) -> None:
        if self.message and time.time() >= self.message_until:
            self.message = ""

    def snapshot_due(self) -> bool:
        return self.force_snapshot or self.state is None or (time.time() - self.last_snapshot_at) >= SNAPSHOT_INTERVAL

    def fetch_snapshot(self) -> SidebarState:
        proc = self.run_controller("snapshot")
        if proc.returncode != 0:
            raise SidebarError(proc.stderr.strip() or proc.stdout.strip() or "failed to fetch sidebar snapshot")

        mode = "unknown"
        active_name = ""
        last_active_name = ""
        sidebar_pane = ""
        focus_pane = ""
        epoch = 0
        width = 0
        height = 0
        entries: List[Entry] = []

        for raw_line in proc.stdout.splitlines():
            if not raw_line:
                continue
            parts = raw_line.split("\t")
            kind = parts[0]
            if kind == "mode":
                mode = parts[1] if len(parts) > 1 else "unknown"
            elif kind == "active_name":
                active_name = parts[1] if len(parts) > 1 else ""
            elif kind == "last_active_name":
                last_active_name = parts[1] if len(parts) > 1 else ""
            elif kind == "sidebar_pane":
                sidebar_pane = parts[1] if len(parts) > 1 else ""
            elif kind == "focus_pane":
                focus_pane = parts[1] if len(parts) > 1 else ""
            elif kind == "epoch":
                epoch = int(parts[1]) if len(parts) > 1 and parts[1] else 0
            elif kind == "size":
                width = int(parts[1]) if len(parts) > 1 and parts[1] else 0
                height = int(parts[2]) if len(parts) > 2 and parts[2] else 0
            elif kind == "entry" and len(parts) >= 13:
                entries.append(
                    Entry(
                        label=parts[1],
                        pane_id=parts[2],
                        window_id=parts[3],
                        window_name=parts[4],
                        kind=parts[5],
                        provider=parts[6],
                        status=parts[7],
                        status_text=parts[8],
                        folder=parts[9],
                        branch=parts[10],
                        command=parts[11],
                        active=(parts[12] == "1"),
                    )
                )

        return SidebarState(
            mode=mode,
            active_name=active_name,
            last_active_name=last_active_name,
            sidebar_pane=sidebar_pane,
            focus_pane=focus_pane,
            epoch=epoch,
            width=width,
            height=height,
            entries=entries,
        )

    def ordered_entries(self, state: SidebarState) -> List[Entry]:
        return state.entries

    def agent_count(self, state: SidebarState) -> int:
        return sum(1 for entry in state.entries if entry.kind == "agent")

    def sync_selection(self, previous: Optional[SidebarState], current: SidebarState) -> None:
        ordered = self.ordered_entries(current)
        if not ordered:
            self.selected_index = 0
            return

        names = [entry.label for entry in ordered]
        if self.selected_index >= len(names):
            self.selected_index = len(names) - 1

        if self.selection_label_hint and self.selection_label_hint in names:
            self.selected_index = names.index(self.selection_label_hint)
            self.selection_label_hint = None
            return

        if previous is None:
            if current.active_name in names:
                self.selected_index = names.index(current.active_name)
            return

        if previous.active_name != current.active_name and current.active_name in names:
            self.selected_index = names.index(current.active_name)

    def compact_state_needs_repair(self, state: SidebarState) -> bool:
        if state.mode != "compact" or not state.entries:
            return False
        if not state.focus_pane:
            return True

        labels = {entry.label for entry in state.entries}
        if not state.active_name or state.active_name not in labels:
            return True

        return not any(entry.active for entry in state.entries)

    def maybe_repair_compact_state(self, state: SidebarState) -> None:
        if not self.compact_state_needs_repair(state):
            return
        now = time.time()
        if now - self.last_repair_attempt_at < 0.5:
            return

        proc = self.run_controller("repair")
        self.last_repair_attempt_at = now
        if proc.returncode == 0:
            self.force_snapshot = True
            self.set_message("repaired compact layout", 1.0)
        else:
            self.set_message(proc.stderr.strip() or proc.stdout.strip() or "failed to repair compact layout", 2.0)

    def maybe_refresh_snapshot(self) -> None:
        if not self.snapshot_due():
            return

        previous = self.state
        current = self.fetch_snapshot()
        self.last_snapshot_at = time.time()
        self.force_snapshot = False

        if previous is None or previous.width != current.width or previous.height != current.height:
            self.redraw_full = True

        self.sync_selection(previous, current)
        self.state = current
        self.maybe_repair_compact_state(current)

    def crop_plain(self, text: str, width: int) -> str:
        if width <= 0:
            return ""
        if len(text) <= width:
            return text
        if width == 1:
            return text[:1]
        return text[: width - 1] + "…"

    def pad_plain(self, text: str, width: int) -> str:
        cropped = self.crop_plain(text, width)
        return cropped + (" " * max(0, width - len(cropped)))

    def render_line(self, plain: str, *styles: str) -> str:
        return "".join(styles) + plain + RESET

    def visible_len(self, text: str) -> int:
        return len(ANSI_RE.sub("", text))

    def pad_ansi(self, text: str, width: int) -> str:
        plain_len = self.visible_len(text)
        if plain_len >= width:
            return text
        return text + (" " * (width - plain_len))

    def status_suffix(self, entry: Entry) -> str:
        if entry.status == "tool":
            return f" ⚙ {entry.status_text}" if entry.status_text else " ⚙"
        if entry.status == "running":
            return " …"
        if entry.status == "done":
            return " ✓"
        if entry.status == "error":
            return " ✗"
        if entry.status == "unknown":
            return " ?"
        return ""

    def entry_display_name(self, entry: Entry) -> str:
        if entry.kind != "agent":
            if entry.folder:
                return entry.folder
            if entry.command and entry.command.lower() not in {"zsh", "bash", "fish", "sh", "tmux"}:
                return entry.command
        return entry.label or entry.folder or entry.command or entry.pane_id

    def entry_secondary(self, entry: Entry) -> str:
        name = self.entry_display_name(entry)
        parts: List[str] = []
        if entry.kind == "agent":
            if entry.folder and entry.folder != name:
                parts.append(entry.folder)
        else:
            if entry.command and entry.command.lower() not in {"zsh", "bash", "fish", "sh", "tmux"}:
                parts.append(entry.command)
            elif entry.folder and entry.folder != name:
                parts.append(entry.folder)
        return " · ".join(parts)

    def entry_row(self, index: int, entry: Entry, selected: bool, width: int) -> str:
        name = self.entry_display_name(entry)
        secondary = self.entry_secondary(entry)
        branch = entry.branch.strip()
        status_suffix = self.status_suffix(entry)
        marker = "●" if entry.active else " "

        plain = f" {marker} {index:>2} {name}"
        if secondary:
            plain += f" · {secondary}"
        if branch:
            plain += f" ({branch})"
        plain += status_suffix

        if selected:
            return self.render_line(self.pad_plain(plain, width), FG_CYAN, BOLD)

        if len(plain) > width:
            truncated = self.pad_plain(plain, width)
            styles: List[str] = []
            if entry.active:
                styles.extend([FG_MAGENTA, BOLD])
            return self.render_line(truncated, *styles)

        parts: List[str] = []
        if entry.active:
            parts.extend([FG_MAGENTA, BOLD, f" {marker} ", RESET])
        else:
            parts.extend([DIM, f" {marker} ", RESET])
        parts.extend([DIM, f"{index:>2} ", RESET])

        if entry.active:
            parts.extend([FG_MAGENTA, BOLD, name, RESET])
        else:
            parts.append(name)
        if secondary:
            parts.extend([DIM, " · ", secondary, RESET])
        if branch:
            parts.extend([DIM, " (", FG_YELLOW, branch, DIM, ")", RESET])
        if entry.status == "tool":
            parts.extend([DIM, " ", FG_YELLOW, "⚙", RESET])
            if entry.status_text:
                parts.extend([DIM, f" {entry.status_text}", RESET])
        elif entry.status == "running":
            parts.extend([DIM, " ", FG_CYAN, "…", RESET])
        elif entry.status == "done":
            parts.extend([DIM, " ", FG_GREEN, "✓", RESET])
        elif entry.status == "error":
            parts.extend([DIM, " ", FG_RED, "✗", RESET])
        elif entry.status == "unknown":
            parts.extend([DIM, " ", FG_RED, "?", RESET])
        return self.pad_ansi("".join(parts), width)

    def build_body_row_specs(self, state: SidebarState) -> List[Tuple[str, Optional[int]]]:
        ordered = self.ordered_entries(state)
        agents_count = self.agent_count(state)
        panes_count = len(ordered) - agents_count
        rows: List[Tuple[str, Optional[int]]] = [("agents-header", None)]

        if agents_count:
            for index in range(agents_count):
                rows.append(("entry", index))
        else:
            rows.append(("no-agents", None))

        rows.append(("blank", None))
        rows.append(("panes-header", None))
        if panes_count:
            for index in range(agents_count, len(ordered)):
                rows.append(("entry", index))
        else:
            rows.append(("no-panes", None))

        return rows

    def render_body_row_spec(
        self, ordered: List[Entry], agents_count: int, width: int, row_kind: str, entry_index: Optional[int]
    ) -> str:
        panes_count = len(ordered) - agents_count

        if row_kind == "agents-header":
            return self.render_line(self.pad_plain(f" Agents ({agents_count}) ", width), BOLD, FG_CYAN)
        if row_kind == "panes-header":
            return self.render_line(self.pad_plain(f" Panes ({panes_count}) ", width), BOLD, FG_GREEN)
        if row_kind == "no-agents":
            return self.render_line(self.pad_plain(" -- no detected coding agents --", width), DIM)
        if row_kind == "no-panes":
            return self.render_line(self.pad_plain(" -- no regular panes --", width), DIM)
        if row_kind == "blank":
            return self.pad_plain("", width)
        if row_kind == "entry" and entry_index is not None and 0 <= entry_index < len(ordered):
            entry = ordered[entry_index]
            return self.entry_row(entry_index + 1, entry, entry_index == self.selected_index, width)
        return self.pad_plain("", width)

    def footer_line_count(self) -> int:
        return 7

    def body_window(self, state: SidebarState, width: int) -> Tuple[int, int, List[Tuple[str, Optional[int]]]]:
        rows = self.build_body_row_specs(state)
        viewport = max(1, max(8, state.height) - self.footer_line_count())
        selected_row = 0
        for idx, (_row_kind, entry_index) in enumerate(rows):
            if entry_index == self.selected_index:
                selected_row = idx
                break

        start = 0
        if selected_row >= viewport:
            start = selected_row - viewport + 1
        visible = rows[start : start + viewport]
        return start, viewport, visible

    def build_lines(self, state: SidebarState) -> List[str]:
        width = max(24, state.width)
        height = max(10, state.height)
        separator = "─" * width
        lines: List[str] = []

        ordered = self.ordered_entries(state)
        agents_count = self.agent_count(state)
        _start, body_height, visible_rows = self.body_window(state, width)
        for row_kind, entry_index in visible_rows:
            lines.append(self.render_body_row_spec(ordered, agents_count, width, row_kind, entry_index))
        while len(lines) < body_height:
            lines.append(self.pad_plain("", width))

        panes_count = len(ordered) - agents_count
        lines.append(self.render_line(self.pad_plain(separator, width), DIM))
        lines.append(self.render_line(self.pad_plain(f" last   {state.last_active_name or '—'}", width), DIM))
        lines.append(self.render_line(self.pad_plain(f" counts a:{agents_count} p:{panes_count}  mode {state.mode or '—'}", width), DIM))
        lines.append(self.render_line(self.pad_plain(" enter switch  esc active", width), FG_GRAY))
        lines.append(self.render_line(self.pad_plain(" j/k move  J/K reorder", width), FG_GRAY))
        lines.append(self.render_line(self.pad_plain(" n/p cycle  1-9 direct  r refresh", width), FG_GRAY))

        if self.message:
            lines.append(self.render_line(self.pad_plain(f" {self.message}", width), FG_YELLOW, BOLD))
        else:
            lines.append(self.pad_plain("", width))

        if len(lines) > height:
            lines = lines[:height]
        while len(lines) < height:
            lines.append(self.pad_plain("", width))
        return lines

    def render(self) -> None:
        if self.state is None:
            return
        lines = self.build_lines(self.state)
        out: List[str] = []

        if self.redraw_full or len(self.last_lines) != len(lines):
            out.append(HOME + CLEAR_SCREEN)
            self.last_lines = [""] * len(lines)
            self.redraw_full = False

        for row, line in enumerate(lines, start=1):
            if row - 1 >= len(self.last_lines) or self.last_lines[row - 1] != line:
                out.append(f"\033[{row};1H{CLEAR_LINE}{line}")

        if out:
            sys.stdout.write("".join(out))
            sys.stdout.flush()
            self.last_lines = list(lines)

    def focus_name(self, name: str, keep_sidebar: bool = False) -> None:
        command = "focus-keep-sidebar" if keep_sidebar else "focus"
        proc = self.run_controller(command, name)
        if proc.returncode != 0:
            raise SidebarError(proc.stderr.strip() or proc.stdout.strip() or f"failed to focus {name}")
        self.force_snapshot = True
        self.set_message(f"focused {name}", 1.0)

    def controller_command(self, command: str, error_message: str) -> None:
        proc = self.run_controller(command)
        if proc.returncode != 0:
            raise SidebarError(proc.stderr.strip() or proc.stdout.strip() or error_message)
        self.force_snapshot = True

    def reorder_selected(self, direction: str) -> None:
        entry = self.selected_entry()
        if entry is None:
            return
        command = "move-up" if direction == "up" else "move-down"
        proc = self.run_controller(command, entry.label)
        if proc.returncode != 0:
            raise SidebarError(proc.stderr.strip() or proc.stdout.strip() or f"failed to move {entry.label}")
        self.selection_label_hint = entry.label
        self.force_snapshot = True
        self.set_message(f"moved {entry.label} {direction}", 1.0)

    def move_selection(self, delta: int) -> None:
        if self.state is None:
            return
        ordered = self.ordered_entries(self.state)
        if not ordered:
            return
        self.selected_index = (self.selected_index + delta) % len(ordered)

    def selected_entry(self) -> Optional[Entry]:
        if self.state is None:
            return None
        ordered = self.ordered_entries(self.state)
        if not ordered:
            return None
        return ordered[self.selected_index]

    def read_key(self, timeout: float) -> Optional[str]:
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if not ready:
            return None

        data = os.read(sys.stdin.fileno(), 1)
        if not data:
            return None

        if data == b"\x1b":
            parts = [data]
            while True:
                more, _, _ = select.select([sys.stdin], [], [], 0.005)
                if not more:
                    break
                chunk = os.read(sys.stdin.fileno(), 32)
                if not chunk:
                    break
                parts.append(chunk)
                if chunk.endswith((b"M", b"m", b"A", b"B", b"C", b"D", b"~")):
                    break
            seq = b"".join(parts)
            if seq.startswith(b"\x1b[A"):
                return "up"
            if seq.startswith(b"\x1b[B"):
                return "down"
            if seq.startswith(b"\x1b[<"):
                return seq.decode("utf-8", "ignore")
            return "escape"

        if data in (b"\r", b"\n"):
            return "enter"
        if data == b"\t":
            return "tab"
        try:
            return data.decode("utf-8")
        except UnicodeDecodeError:
            return None

    def handle_mouse(self, sequence: str) -> bool:
        if self.state is None:
            return False
        match = re.match(r"\x1b\[<([0-9]+);([0-9]+);([0-9]+)([Mm])", sequence)
        if not match:
            return False
        button = int(match.group(1))
        _x = int(match.group(2))
        y = int(match.group(3))
        kind = match.group(4)

        if kind != "M":
            return True

        if button == 64:
            self.move_selection(-1)
            return True
        if button == 65:
            self.move_selection(1)
            return True

        width = max(24, self.state.width)
        _start, _body_height, visible_rows = self.body_window(self.state, width)
        row_index = y - 1
        if 0 <= row_index < len(visible_rows):
            entry_index = visible_rows[row_index][1]
            if entry_index is not None and 0 <= entry_index < len(self.ordered_entries(self.state)):
                self.selected_index = entry_index
                entry = self.ordered_entries(self.state)[entry_index]
                self.focus_name(entry.label, keep_sidebar=True)
            return True
        return False

    def handle_key(self, key: str) -> None:
        if self.state is None:
            return
        if key == "up" or key == "k":
            self.move_selection(-1)
            return
        if key == "down" or key == "j":
            self.move_selection(1)
            return
        if key == "g":
            self.selected_index = 0
            return
        ordered = self.ordered_entries(self.state)
        if key == "G" and ordered:
            self.selected_index = len(ordered) - 1
            return
        if key == "enter":
            entry = self.selected_entry()
            if entry is not None:
                self.focus_name(entry.label, keep_sidebar=True)
            return
        if key == "K":
            self.reorder_selected("up")
            return
        if key == "J":
            self.reorder_selected("down")
            return
        if key in ("escape", "q"):
            self.controller_command("focus-right", "failed to focus active pane")
            self.set_message("focused active pane", 1.0)
            return
        if key == "r":
            self.force_snapshot = True
            self.set_message("refreshed", 0.8)
            return
        if key == "n":
            self.controller_command("next-keep-sidebar", "failed to focus next entry")
            return
        if key == "p":
            self.controller_command("prev-keep-sidebar", "failed to focus previous entry")
            return
        if key and key.isdigit() and key != "0":
            index = int(key) - 1
            if 0 <= index < len(ordered):
                self.selected_index = index
                self.focus_name(ordered[index].label, keep_sidebar=True)
            else:
                self.set_message(f"no entry {key}", 1.2)
            return
        if key.startswith("\x1b[<"):
            self.handle_mouse(key)

    def run(self) -> int:
        signal.signal(signal.SIGWINCH, lambda *_args: setattr(self, "redraw_full", True))
        with TerminalController():
            while True:
                self.clear_message_if_expired()
                self.maybe_refresh_snapshot()
                self.render()
                key = self.read_key(INPUT_POLL_INTERVAL)
                if key is None:
                    continue
                try:
                    self.handle_key(key)
                except SidebarError as error:
                    self.set_message(str(error), 2.0)
                self.render()
        return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", required=True)
    parser.add_argument("--controller", required=True)
    args = parser.parse_args()

    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("agents-sidebar: stdin/stdout must be a tty", file=sys.stderr)
        return 1

    try:
        return SidebarApp(args.session, args.controller).run()
    except KeyboardInterrupt:
        return 0
    except Exception as error:
        print(f"agents-sidebar: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
