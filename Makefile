# greenfield quality gates.
#
# `make commit` is the local gate; it does not create a Git commit. This repository has no
# CI (backlog/G003-ci-for-greenfield.md adds it), so `make commit` is the only gate.
#
# External commands: shellcheck (lint), and glossarian and llm-size-guard (template-check
# and llm-size-guard). The operator runs `make install-linters` (an agent hands it over)
# to install all three at pinned versions. An agent may run every other target.

UV ?= uv

# The shell scripts of this repository: the init script and its tests; the review linter
# and the change log tool under template/tools/, which are placed in every new
# repository; and their tests under tools/, which are not placed.
SHELL_SRC := greenfield_init.sh greenfield_init_test.sh \
             template/tools/review_lint.sh template/tools/change_log.sh \
             template/tools/change_log_list.sh template/tools/change_log_new.sh \
             template/tools/change_log_upstream.sh template/tools/change_log_merge.sh \
             tools/review_lint_test.sh tools/review_lint_test_lib.sh \
             tools/change_log_test.sh tools/change_log_new_test.sh \
             tools/change_log_merge_test.sh tools/change_log_sync_test.sh \
             tools/change_log_safe_test.sh tools/change_log_test_lib.sh

# Pinned linters. The first two must match the pins in template/Makefile, which is what a
# new repository installs from; `make lint` checks that they do.
GLOSSARIAN_URL      := git+https://github.com/bryant-quist-vgs/glossarian.git
GLOSSARIAN_REF      := 392ef31406ba156fcca0dee77e865ac30230c676
LLM_SIZE_GUARD_URL  := git+https://github.com/bryant-quist-vgs/llm_file_size_guard.git
LLM_SIZE_GUARD_REF  := 98271c1c7f0c6f603cc0d62977f7b780529aeae7
SHELLCHECK_PY       := shellcheck-py==0.10.0.1

.DEFAULT_GOAL := help

.PHONY: help lint test template-check llm-size-guard commit install-linters \
        require-shellcheck require-llm-size-guard

help:
	@echo "Targets:"
	@echo "  lint             shell syntax, shellcheck, and the linter pins of template/Makefile"
	@echo "  test             the tests of greenfield_init.sh, the review linter, and the change log tool"
	@echo "  template-check   place the template in a scratch repository and run its gates there"
	@echo "  llm-size-guard   fail when a file here or in the template is too large"
	@echo "  commit           every gate above; run before calling a change done (creates no Git commit)"
	@echo "  install-linters  the operator runs this: install shellcheck, glossarian, and llm-size-guard at pinned versions"

# The pins are compared as text so that the template cannot drift from what is tested here.
lint: require-shellcheck
	@for f in $(SHELL_SRC); do bash -n "$$f" || exit 1; done
	shellcheck -x $(SHELL_SRC)
	@for pin in "GLOSSARIAN_REF      := $(GLOSSARIAN_REF)" "LLM_SIZE_GUARD_REF  := $(LLM_SIZE_GUARD_REF)"; do \
	  grep -qxF "$$pin" template/Makefile || { \
	    echo "Error: template/Makefile does not carry the pin: $$pin" >&2; exit 1; }; \
	done

test:
	bash greenfield_init_test.sh
	bash tools/review_lint_test.sh
	bash tools/change_log_test.sh
	bash tools/change_log_new_test.sh
	bash tools/change_log_merge_test.sh
	bash tools/change_log_sync_test.sh
	bash tools/change_log_safe_test.sh

# Places the template with greenfield_init.sh and requires that the placed repository
# holds no test and no contract of the tools: those are kept here, under tools/. It then
# runs, in the placed repository, the gates start-here.md says pass on an untouched
# repository. `make change-log` is run there twice: before any commit, and again after
# a first commit of the untouched files, which is made with a fixed identity and none of
# the account's Git configuration. It then requires `make stubs` and `make commit` to
# fail there: markers remain, and no toolchain is wired. Last, it checks what the placed
# Makefile does with TITLE, TAGS, and UPSTREAM: they reach the change log tool as typed,
# and `make` runs nothing they hold.
#
# The scratch repository is made in a temporary directory outside this one, because an
# agent's sandbox does not allow `git init` beneath its own working directory.
template-check:
	@stamp=$$(mktemp -d "$${TMPDIR:-/tmp}/greenfield-stamp.XXXXXX") || exit 2; \
	trap 'rm -rf "$$stamp"' EXIT; \
	bash greenfield_init.sh --target "$$stamp/repo" --name "Template Check" \
	  --owner "Greenfield Maintainer" --date 2026-01-01 >/dev/null || exit 1; \
	for f in "$$stamp/repo"/tools/*_test*.sh "$$stamp/repo"/tools/*_contract.md; do \
	  if [ -e "$$f" ] || [ -L "$$f" ]; then \
	    echo "Error: the template places a test or a contract of a tool: tools/$${f##*/}" >&2; exit 1; fi; \
	done; \
	git -C "$$stamp/repo" init -q || exit 1; \
	$(MAKE) -C "$$stamp/repo" change-log docs-lint llm-size-guard reviews-lint || exit 1; \
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$$stamp/repo" \
	  -c user.name=template-check -c user.email=template-check@example.invalid \
	  -c commit.gpgsign=false -c core.hooksPath=/dev/null add -A || exit 1; \
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$$stamp/repo" \
	  -c user.name=template-check -c user.email=template-check@example.invalid \
	  -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "the untouched files" || exit 1; \
	$(MAKE) -C "$$stamp/repo" change-log || exit 1; \
	if $(MAKE) -C "$$stamp/repo" stubs >/dev/null 2>&1; then \
	  echo "Error: 'make stubs' passed on a fresh stamp; the stub markers are not being found." >&2; exit 1; fi; \
	if $(MAKE) -C "$$stamp/repo" commit >/dev/null 2>&1; then \
	  echo "Error: 'make commit' passed on a fresh stamp with no toolchain wired." >&2; exit 1; fi; \
	git -C "$$stamp/repo" check-ignore -q docs/change_log.md.tmp.1 || { \
	  echo "Error: the placed .gitignore does not ignore the temporary file of the change log." >&2; exit 1; }; \
	$(MAKE) -C "$$stamp/repo" change-log UPSTREAM=HEAD | grep -q 'upstream HEAD at ' || { \
	  echo "Error: 'make change-log UPSTREAM=HEAD' did not take HEAD for the upstream." >&2; exit 1; }; \
	if $(MAKE) -C "$$stamp/repo" change-log UPSTREAM='$$(shell touch MADE-BY-MAKE)' >/dev/null 2>&1; then \
	  echo "Error: 'make change-log' passed with an UPSTREAM that is no ref name." >&2; exit 1; fi; \
	title='Pass $$(shell touch MADE-BY-MAKE) and $$HOME as typed'; \
	$(MAKE) -C "$$stamp/repo" change-log-entry TITLE="$$title" TAGS='process, fix' >"$$stamp/entry.out" || exit 1; \
	entry=$$(grep -m 1 '^docs/change_log/' "$$stamp/entry.out"); \
	grep -qxF "title: \"$$title\"" "$$stamp/repo/$$entry" || { \
	  echo "Error: 'make change-log-entry' did not pass TITLE to the script as typed." >&2; exit 1; }; \
	if [ -e "$$stamp/repo/MADE-BY-MAKE" ]; then \
	  echo "Error: make ran a command that TITLE or UPSTREAM held." >&2; exit 1; fi; \
	echo "template-check: a fresh stamp passes its change log, documentation, and review gates"

# Run against a throwaway index that names every file, tracked or not, so that a new file
# is checked before its first commit. The real index is not touched.
llm-size-guard: require-llm-size-guard
	@mkdir -p .gate-scratch
	@rm -f .gate-scratch/index
	@GIT_INDEX_FILE=.gate-scratch/index git add --intent-to-add -- .
	GIT_INDEX_FILE=.gate-scratch/index llm-size-guard check

commit: lint test template-check llm-size-guard
	@echo "commit gate: all checks passed"

install-linters:
	$(UV) tool install --force "$(SHELLCHECK_PY)"
	$(UV) tool install --force "$(GLOSSARIAN_URL)@$(GLOSSARIAN_REF)"
	$(UV) tool install --force "$(LLM_SIZE_GUARD_URL)@$(LLM_SIZE_GUARD_REF)"

require-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { \
	  echo "Error: shellcheck is not on PATH. The operator installs it with: make install-linters (an agent hands it over)" >&2; \
	  exit 1; }

require-llm-size-guard:
	@command -v llm-size-guard >/dev/null 2>&1 || { \
	  echo "Error: llm-size-guard is not on PATH. The operator installs it with: make install-linters (an agent hands it over)" >&2; \
	  exit 1; }
