---
name: linter-installs
description: The operator runs make install-linters (an agent hands it over); on the owner's machine it force-replaces tools the owner develops.
type: tooling
date: 2026-11-18
---

`make install-linters`, here and in every placed repository, runs
`uv tool install --force` for glossarian and llm-size-guard at pinned commits; here it
also installs shellcheck (`shellcheck-py`) at a pinned version. The owner develops
glossarian and llm-size-guard and has them installed in `~/.local/bin`; a forced install
replaces whatever build is there.

**Why:** this is the agent's inference, not something the owner said. On 2026-11-18 the
installed tools were used as found and `install-linters` was not run.

**How to apply:** the operator runs `make install-linters` (an agent hands it over). On
the owner's machine, use the linters already on `PATH`, and hand the command over only
when the owner asks for it; CI and other clean environments run it as a step. When either
tool's `main` moves and the template should follow, change the pin in both `Makefile` and
`template/Makefile` (`make lint` checks that they match) and run `make template-check`
against a build of the new commit.
