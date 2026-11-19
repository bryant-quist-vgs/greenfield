# @@PROJECT_NAME@@ quality gates.
#
# `make commit` is the local pre-commit aggregate and the only gate CI runs, so a gate
# cannot exist in one place and not the other. It does not create a Git commit.
#
# An agent may run every target except `install-linters`. The operator runs
# `make install-linters` (an agent hands it over).
#
# The documentation gates use two external tools: glossarian (the commands
# glossarian-check and glossarian-gather) and llm-size-guard. `make install-linters`
# installs both at the commits pinned below, and CI installs them the same way. The
# change-log and reviews-lint gates use only the scripts under tools/, which the
# greenfield repository maintains: their contracts and tests are kept there, and no
# test of them runs here. The language gates (format, format-check, lint, test) are not
# wired: they fail until the toolchain change (backlog/B001-language-toolchain.md) wires
# them. A gate with nothing configured fails; it never passes unchecked.

UV ?= uv

# The repository's own files: tracked or not yet tracked, never ignored ones.
REPO_FILES := git ls-files --cached --others --exclude-standard

# Gates keep throwaway files in .gate-scratch/, which Git ignores and which holds nothing
# else. The path is written out wherever it is used, and is not a variable, so that no
# setting from the command line or the environment can aim a removal at another directory.

# Pinned documentation linters. Bump a commit here, in one place, to upgrade.
GLOSSARIAN_URL      := git+https://github.com/bryant-quist-vgs/glossarian.git
GLOSSARIAN_REF      := 392ef31406ba156fcca0dee77e865ac30230c676
LLM_SIZE_GUARD_URL  := git+https://github.com/bryant-quist-vgs/llm_file_size_guard.git
LLM_SIZE_GUARD_REF  := 98271c1c7f0c6f603cc0d62977f7b780529aeae7

NOT_WIRED = @echo "Error: '$@' is not wired to a toolchain yet. See backlog/B001-language-toolchain.md." >&2; exit 2

.DEFAULT_GOAL := help

# One gate at a time, in the order written: `change-log` can change the working tree, and
# the gates after it judge the tree it leaves.
.NOTPARALLEL:

.PHONY: help format format-check lint test docs-lint llm-size-guard reviews-lint \
        change-log change-log-entry commit stubs install-linters \
        require-glossarian require-llm-size-guard

help:
	@echo "Targets:"
	@echo "  format           apply the code formatter              (not wired: backlog B001)"
	@echo "  format-check     verify formatting, change nothing     (not wired: backlog B001)"
	@echo "  lint             static checks on source and tests     (not wired: backlog B001)"
	@echo "  test             the deterministic test suite          (not wired: backlog B001)"
	@echo "  docs-lint        validate docs/glossary.md and every glossary link in the repository"
	@echo "  llm-size-guard   fail when a repository file is too large for LLM maintenance"
	@echo "  reviews-lint     check every review record and disposition file under reviews/"
	@echo "  change-log       merge the upstream into a clean working tree where the merge is"
	@echo "                   trivial, regenerate docs/change_log.md, and check the change log;"
	@echo "                   under CI, check only."
	@echo "                   UPSTREAM=<ref> names the upstream, here and under commit"
	@echo "  commit           change-log first, then every gate above except format; run before"
	@echo "                   committing (it creates no Git commit)"
	@echo "  change-log-entry create a change log entry: make change-log-entry TITLE=\"...\" TAGS=\"...\""
	@echo "  stubs            list the GREENFIELD-STUB markers that remain; fails if any do"
	@echo "  install-linters  the operator runs this one: installs glossarian and llm-size-guard"
	@echo "                   at the pinned commits (an agent hands it over)"

format:
	$(NOT_WIRED)

format-check:
	$(NOT_WIRED)

lint:
	$(NOT_WIRED)

test:
	$(NOT_WIRED)

# The glossary governs the whole repository, so links are resolved in every Markdown file
# of the repository, not only under docs/. glossarian-gather scans a directory and knows
# nothing of .gitignore, so it is given a copy that holds the repository's Markdown and
# nothing else. A file deleted from the working tree but not yet from the index is left
# out; a file whose name Git prints in quotes (unusual characters) fails the gate, because
# it could not be copied under that name and would otherwise go unchecked.
docs-lint: require-glossarian
	glossarian-check docs/glossary.md
	@rm -rf .gate-scratch/docs
	@mkdir -p .gate-scratch/docs
	@$(REPO_FILES) -- '*.md' | \
	while IFS= read -r file; do \
	  case "$$file" in \
	    \"*) echo "Error: docs-lint cannot read the file name $$file (Git quotes it); rename the file." >&2; exit 1 ;; \
	  esac; \
	  if [ -f "$$file" ]; then \
	    mkdir -p ".gate-scratch/docs/$$(dirname "$$file")" && \
	    cp "$$file" ".gate-scratch/docs/$$file" || exit 1; \
	  fi; \
	done
	@test -f .gate-scratch/docs/docs/glossary.md || { \
	  echo "Error: docs-lint found no Markdown to check; run it from the root of the Git repository." >&2; \
	  exit 1; }
	glossarian-gather .gate-scratch/docs --repo-root .gate-scratch/docs --failures

# The guard's accept and defer state is the tracked file named in
# .llm-file-size-guard.toml, so a suppression is a reviewable change.
#
# The guard takes its file list from the Git index, so on its own it would not see a file
# before that file's first commit. It is run against a throwaway index that names every
# repository file, tracked or not (`--intent-to-add` records names only). The real index
# is not touched.
llm-size-guard: require-llm-size-guard
	@mkdir -p .gate-scratch
	@rm -f .gate-scratch/index
	@GIT_INDEX_FILE=.gate-scratch/index git add --intent-to-add -- .
	GIT_INDEX_FILE=.gate-scratch/index llm-size-guard check

reviews-lint:
	bash tools/review_lint.sh

# TITLE, TAGS, and UPSTREAM reach the script as typed: `make` expands nothing in them and
# the shell reads nothing in them, so `$(shell ...)`, `$HOME`, a quote, or a backtick in a
# title runs nothing. The technique: `$(value NAME)` reads the variable unexpanded, `:=`
# stores that text unexpanded, and the script receives it through the environment under
# another name, so it is never part of a recipe. `unexport` keeps `make` from exporting
# the three variables themselves, which would expand them. UPSTREAM is taken from the
# command line only, never from the environment.
unexport TITLE TAGS UPSTREAM
export CHANGE_LOG_TITLE := $(value TITLE)
export CHANGE_LOG_TAGS := $(value TAGS)
export CHANGE_LOG_UPSTREAM := $(if $(filter command,$(firstword $(origin UPSTREAM))),$(value UPSTREAM))

# Outside CI this gate writes: it merges the upstream when that is not merged, nothing
# in the working tree is uncommitted, and the merge is trivial; and it regenerates
# docs/change_log.md. It contacts no remote and creates no Git commit;
# `git commit --no-edit` completes a merge it makes. Under CI, where
# the CI variable is set to any value, it checks and changes nothing. `UPSTREAM=<ref>`
# names the upstream in place of the default branch of origin, here and under `commit`.
change-log:
	@if [ -n "$$CHANGE_LOG_UPSTREAM" ]; then set -- --upstream "$$CHANGE_LOG_UPSTREAM"; fi; \
	echo "bash tools/change_log.sh $(if $(value CI),check,sync)$${1:+ --upstream <UPSTREAM>}"; \
	bash tools/change_log.sh $(if $(value CI),check,sync) "$$@"

change-log-entry:
	@bash tools/change_log.sh new --title "$$CHANGE_LOG_TITLE" --tags "$$CHANGE_LOG_TAGS"

# Order: change-log first, so that every other gate judges the merged tree; then the
# cheapest and most local, so a formatting slip fails in seconds.
commit: change-log format-check lint docs-lint reviews-lint test llm-size-guard
	@echo "commit gate: all checks passed"

# Not part of `commit`: markers are expected until the design is written. The design exit
# gate (docs/greenfield/start-here.md) requires this target to pass.
stubs:
	@git grep -n --untracked --exclude-standard -e '^> \*\*GREENFIELD-STUB\*\*' -- '*.md'; \
	status=$$?; \
	if [ "$$status" -eq 0 ]; then \
	  echo "Error: the stub markers above remain; write the content they describe." >&2; exit 1; \
	elif [ "$$status" -eq 1 ]; then \
	  echo "stubs: no stub markers remain"; \
	else \
	  echo "Error: could not search for stub markers (git grep exited $$status)." >&2; exit 2; \
	fi

install-linters:
	$(UV) tool install --force "$(GLOSSARIAN_URL)@$(GLOSSARIAN_REF)"
	$(UV) tool install --force "$(LLM_SIZE_GUARD_URL)@$(LLM_SIZE_GUARD_REF)"

# A missing documentation linter fails the gate. Skipping would let a broken glossary
# through on any machine that never installed the tool.
require-glossarian:
	@command -v glossarian-check >/dev/null 2>&1 && command -v glossarian-gather >/dev/null 2>&1 || { \
	  echo "Error: glossarian-check and glossarian-gather are not on PATH." >&2; \
	  echo "The operator installs them with: make install-linters (an agent hands it over)" >&2; \
	  exit 1; }

require-llm-size-guard:
	@command -v llm-size-guard >/dev/null 2>&1 || { \
	  echo "Error: llm-size-guard is not on PATH." >&2; \
	  echo "The operator installs it with: make install-linters (an agent hands it over)" >&2; \
	  exit 1; }
