import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

type SidebarStatus = "idle" | "running" | "tool" | "done" | "error" | "unknown";

const paneId = process.env.TMUX_PANE;
const DONE_TTL_MS = 5000;

export default function agentsSidebarStatusExtension(pi: ExtensionAPI) {
	let sessionId: string | undefined;
	let currentStatus: SidebarStatus = "idle";
	let sawErrorInRun = false;
	let doneTimer: ReturnType<typeof setTimeout> | undefined;

	const inTmux = Boolean(paneId);

	function clearDoneTimer(): void {
		if (doneTimer) {
			clearTimeout(doneTimer);
			doneTimer = undefined;
		}
	}

	async function tmux(args: string[]): Promise<string | undefined> {
		if (!inTmux) return undefined;
		const result = await pi.exec("tmux", args);
		if (result.code !== 0) return undefined;
		return result.stdout.trim();
	}

	async function ensureSessionId(): Promise<string | undefined> {
		if (!inTmux) return undefined;
		if (sessionId) return sessionId;
		sessionId = await tmux(["display-message", "-p", "-t", paneId!, "#{session_id}"]);
		return sessionId;
	}

	function sidebarPaneOptionName(suffix: string): string {
		return `@agents_sidebar_${suffix}_${paneId!.slice(1)}`;
	}

	function pathLabel(path: string): string {
		const parts = path.split("/").filter(Boolean);
		return parts[parts.length - 1] ?? path;
	}

	function indicatorForStatus(status: SidebarStatus): string {
		switch (status) {
			case "running":
				return "[●]";
			case "tool":
				return "[⚙]";
			case "done":
				return "[✓]";
			case "error":
				return "[✗]";
			case "idle":
				return "[·]";
			default:
				return "[?]";
		}
	}

	async function setSessionOption(name: string, value?: string): Promise<void> {
		const sid = await ensureSessionId();
		if (!sid) return;
		if (value === undefined || value === "") {
			await pi.exec("tmux", ["set-option", "-qu", "-t", sid, name]);
			return;
		}
		await pi.exec("tmux", ["set-option", "-q", "-t", sid, name, value]);
	}

	async function setPaneOption(name: string, value?: string): Promise<void> {
		if (!inTmux) return;
		if (value === undefined || value === "") {
			await pi.exec("tmux", ["set-option", "-pqu", "-t", paneId!, name]);
			return;
		}
		await pi.exec("tmux", ["set-option", "-pq", "-t", paneId!, name, value]);
	}

	async function bumpEpoch(): Promise<void> {
		await setSessionOption("@agents_sidebar_epoch", `${Date.now()}`);
	}

	async function setSidebarPaneMeta(suffix: string, value?: string): Promise<void> {
		await setSessionOption(sidebarPaneOptionName(suffix), value);
	}

	function renderFooterStatus(ctx: ExtensionContext, status: SidebarStatus, statusText = ""): void {
		if (!ctx.hasUI) return;
		const theme = ctx.ui.theme;
		let text = theme.fg("dim", "π sidebar ");
		if (status === "tool") {
			text += theme.fg("warning", "⚙");
			text += theme.fg("dim", ` ${statusText || "tool"}`);
		} else if (status === "running") {
			text += theme.fg("accent", "●");
			text += theme.fg("dim", " running");
		} else if (status === "done") {
			text += theme.fg("success", "✓");
			text += theme.fg("dim", " finished");
		} else if (status === "error") {
			text += theme.fg("error", "✗");
			text += theme.fg("dim", " errored");
		} else if (status === "idle") {
			text += theme.fg("dim", "waiting");
		} else {
			text += theme.fg("warning", "?");
			text += theme.fg("dim", " unknown");
		}
		ctx.ui.setStatus("agents-sidebar", text);
	}

	async function seedLabelIfMissing(ctx: ExtensionContext): Promise<void> {
		const sid = await ensureSessionId();
		if (!sid) return;
		const existing = await tmux(["show-option", "-qv", "-t", sid, sidebarPaneOptionName("name")]);
		if (existing) return;

		const title = await tmux(["display-message", "-p", "-t", paneId!, "#{pane_title}"]);
		if (title?.startsWith("π - ")) {
			await setSidebarPaneMeta("name", title.slice(4));
			return;
		}

		const cwdBase = pathLabel(ctx.cwd || "");
		if (cwdBase) {
			await setSidebarPaneMeta("name", cwdBase);
		}
	}

	async function publishState(ctx: ExtensionContext, status: SidebarStatus, statusText = ""): Promise<void> {
		if (!inTmux) return;
		clearDoneTimer();
		currentStatus = status;
		await setSidebarPaneMeta("kind", "agent");
		await setSidebarPaneMeta("provider", "pi");
		await setSidebarPaneMeta("status", status);
		await setSidebarPaneMeta("status_text", status === "tool" ? statusText : undefined);
		await setSidebarPaneMeta("last_done", status === "done" ? `${Math.floor(Date.now() / 1000)}` : undefined);
		await setPaneOption("@pi_session_state", status);
		await setPaneOption("@pi_session_indicator", indicatorForStatus(status));
		await bumpEpoch();
		renderFooterStatus(ctx, status, statusText);
	}

	async function publishIdle(ctx: ExtensionContext): Promise<void> {
		sawErrorInRun = false;
		await publishState(ctx, "idle");
	}

	if (!inTmux) return;

	pi.on("session_start", async (_event, ctx) => {
		await ensureSessionId();
		await seedLabelIfMissing(ctx);
		await publishIdle(ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		clearDoneTimer();
		sawErrorInRun = false;
		await publishState(ctx, "running");
	});

	pi.on("tool_execution_start", async (event, ctx) => {
		await publishState(ctx, "tool", event.toolName);
	});

	pi.on("tool_execution_end", async (event, ctx) => {
		if (event.isError) {
			sawErrorInRun = true;
		}
		await publishState(ctx, "running");
	});

	pi.on("turn_end", async (_event, ctx) => {
		if (currentStatus !== "done" && currentStatus !== "error") {
			await publishState(ctx, "running");
		}
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (sawErrorInRun) {
			await publishState(ctx, "error");
			return;
		}
		await publishState(ctx, "done");
		doneTimer = setTimeout(() => {
			void publishIdle(ctx);
		}, DONE_TTL_MS);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		clearDoneTimer();
		await publishIdle(ctx);
		if (ctx.hasUI) {
			ctx.ui.setStatus("agents-sidebar", undefined);
		}
	});
}
