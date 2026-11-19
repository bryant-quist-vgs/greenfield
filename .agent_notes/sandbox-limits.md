---
name: sandbox-limits
description: What the agent sandbox blocks in this repository, as observed on 2026-11-18, and how the gates work inside it.
type: environment
date: 2026-11-18
---

Observed in a Claude Code session on the owner's Mac on 2026-11-18. Check again before
relying on it; sandbox settings change.

- **`git init` fails beneath the working directory.** Git cannot write `.git/hooks` or
  `.git/config` for a new repository under this one. `git init` under `$TMPDIR` works.
  That is why `make template-check` places its scratch repository with `mktemp` under
  `$TMPDIR`, and why both test suites build their repositories there.
- **Running an interpreter on a file directly is refused** (`bash script.sh`,
  `python3 -`), while `make <target>` is allowed. Run scripts and tests through the
  Makefile.
- **`uvx` cannot write to `~/.local/share/uv/tools`.** With `UV_TOOL_DIR` and
  `UV_TOOL_BIN_DIR` pointed at directories under `$TMPDIR`,
  `uvx --from shellcheck-py==0.10.0.1 shellcheck ...` runs without installing anything.
- **A hook caps command output** and asks for long output to go to a file. `AGENTS.md`,
  here and in the template, tells agents to use `local/`, which `.gitignore` ignores in
  both.
- **A test that runs a command reading standard input blocks under `make`** in this
  harness, where standard input is left open. Give such a run `</dev/null` in the test
  itself (the init tests' "drains standard input" case does).
- **`make commit` needs `shellcheck` on `PATH`,** and on 2026-11-18 it was not installed
  on the owner's machine. The gate runs in full with a copy installed under `$TMPDIR`, as
  an agent ran it that day: `UV_TOOL_DIR="$TMPDIR/uv-tools"
  UV_TOOL_BIN_DIR="$TMPDIR/uv-bin" uv tool install shellcheck-py==0.10.0.1`, then
  `PATH="$TMPDIR/uv-bin:$PATH" make commit </dev/null`. This touches nothing outside
  `$TMPDIR`, unlike `make install-linters`, which the operator runs.

**How to apply:** when a gate fails here with "Operation not permitted", suspect the
sandbox before the gate. Do not work around a block by another route; build the gate so
that it does not need what is blocked, as `template-check` is built.
