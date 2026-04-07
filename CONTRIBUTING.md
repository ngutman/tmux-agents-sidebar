# Contributing

Issues and pull requests are welcome.

## Before sending changes

- read `AGENTS.md` and the relevant docs in `docs/`
- run `./run_tests`
- run `bash -n` on shell entrypoints
- run `python3 -m py_compile scripts/agents-sidebar.py`
- keep tmux behavior compatible with both compact and wide mode
- update docs when commands, setup, install steps, or state semantics change

## Style

- keep shell changes small and explicit
- prefer simple tmux formats over expensive runtime probing
- keep the sidebar responsive; avoid introducing slow per-refresh logic
- preserve compatibility with manual installation and TPM-style plugin loading
