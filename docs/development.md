# Development

## Repository layout

```text
tmux-agents-sidebar.tmux   # canonical tmux plugin entrypoint
plugin.tmux                # compatibility wrapper
scripts/
  agents-sidebar           # controller / tmux integration
  agents-sidebar.py        # interactive sidebar UI
tests/
run_tests
integrations/pi/
docs/
```

## Running tests

```bash
cd ~/projects/tmux-agents-sidebar
./run_tests
```

The test suite is a lightweight shell integration setup inspired by common tmux plugin repository layouts (`run_tests` plus executable `tests/test_*.sh` files).

## Manual checks

Syntax / basic validation:

```bash
bash -n tmux-agents-sidebar.tmux plugin.tmux run_tests scripts/agents-sidebar tests/test_*.sh tests/helpers/test_lib.sh
python3 -m py_compile scripts/agents-sidebar.py
```

Optional TypeScript smoke test for the Pi integration file:

```bash
npx tsx -e "import('./integrations/pi/agents-sidebar-status.ts').then(() => console.log('ok'))"
```

## Local development install

```bash
mkdir -p ~/.tmux/plugins
ln -sfn ~/projects/tmux-agents-sidebar ~/.tmux/plugins/tmux-agents-sidebar
tmux source-file ~/.tmux.conf
```

If you are working on the Pi integration too, link the extension and run `/reload` in Pi after each change.
