#!/usr/bin/env bash
# greenfield_init_test.sh — Tests for greenfield_init.sh, contract v4.
# Coverage:
#   - Happy path: the real template is placed in an absent directory, every token is
#     replaced, and the stamp is written.
#   - Load-bearing (files as placed): every template file arrives at its path.
#   - Load-bearing (stamp): its six lines; a second run is refused because of it.
#   - Load-bearing (exit code): 0 placed, 1 refused, 2 usage.
#   - Load-bearing (validation before sed): hostile --name and --owner are rejected,
#     nothing is executed, and a legitimate unusual owner is written literally.
#   - Load-bearing (never overwrite): a conflict refuses and writes nothing;
#     --keep-existing keeps the file byte for byte; .gitignore is appended to.
#   - Symbolic links in the target are refused; nothing is written outside the target.
#   - Template checks: a link, an unknown token (in a binary file too), a path with a
#     control character, its own stamp, no files, an unreadable directory; no .DS_Store.
#   - Dry run: prints the plan, creates nothing, changes nothing in an existing target.
#   - Load-bearing (no-clobber, stamp means complete): a file or a stamp that appears
#     after the plan stops the run and is not overwritten; a command that drains
#     standard input does not cut the placement short.
#   - A target named - or -P, an exported CDPATH or GIT_DIR change nothing; a target that
#     is a link to a directory is followed; one with a newline is refused.
#   - Version and commit: unknown outside Git or beneath a work tree, HEAD when clean,
#     +dirty when changed; a malformed or unreadable VERSION is an error.
#   - Capability boundary: a run changes nothing outside the target, including the
#     script's own directory and its Git index, and needs no temporary file.
# Everything is built in a temporary directory. The real template is read by the
# happy-path tests; the others use small templates made here. The script is run in a
# UTF-8 locale where one is installed, so that its byte limits are shown to be bytes.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
init="$here/greenfield_init.sh"

work=$(mktemp -d "${TMPDIR:-/tmp}/greenfield-init-test.XXXXXX") || exit 2
trap 'rm -rf "$work"' EXIT

passed=0 failed=0 output="" status=0
ok() { passed=$((passed + 1)); }
fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'
}

# check <name> <command> [<args>...]: the command must succeed.
check() {
  local label=$1; shift
  if "$@"; then ok; else fail "$label" "$output"; fi
}

utf8=$(locale -a 2>/dev/null | grep -i -m 1 -E '^(en_US|C)\.utf-?8$')
run() {
  output=$(LC_ALL="$utf8" bash "$init" "$@" 2>&1)
  status=$?
}

exited() { [ "$status" -eq "$1" ]; }
same() { [ "$1" = "$2" ]; }
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
empty_dir() { [ -z "$(ls -A "$1")" ]; }
out_has() { printf '%s\n' "$output" | grep -q -- "$1"; }

nl=$'\n' tab=$'\t'
listing() { # every file and link under a directory, with content checksums
  (cd "$1" && find . \( -type f -o -type l \) -exec cksum {} + 2>/dev/null | sort)
}

# A small template with one of everything the script treats specially.
small_template() {
  local t="$work/template.$1"
  mkdir -p "$t/docs/sub"
  printf '# @@PROJECT_NAME@@\nOwner: @@OWNER@@ on @@DATE@@\n' >"$t/README.md"
  printf 'v@@GREENFIELD_VERSION@@ at @@GREENFIELD_COMMIT@@\n' >"$t/docs/sub/version.md"
  printf '/local/\n' >"$t/.gitignore"
  # shellcheck disable=SC2016
  printf 'help:\n\t@echo "$@ | a & b"\n' >"$t/Makefile"
  printf '%s' "$t"
}

# --- Happy path, real template ------------------------------------------------
t1="$work/happy"
owner="Zoë O'Brien-Smith, Jr."
run --target "$t1" --name "Sample Project" --owner "$owner" --date 2026-01-31
check "happy path exits 0" exited 0
for f in AGENTS.md CLAUDE.md .agent_notes/index.md README.md Makefile .gitignore \
  .llm-file-size-guard.toml .github/workflows/ci.yml docs/design.md docs/glossary.md \
  docs/decisions.md docs/decisions/d01-starts-from-greenfield-default.md \
  docs/open-questions.md docs/out-of-scope.md docs/deferred-work.md docs/threat-model.md \
  docs/sandbox-testing.md docs/greenfield/start-here.md docs/greenfield/specification.md \
  docs/greenfield/adversarial-review.md docs/greenfield/review-rubric.md \
  backlog/README.md backlog/B001-language-toolchain.md reviews/TEMPLATE-record.md \
  reviews/TEMPLATE-disposition.md tools/review_lint.sh tools/review_lint_record.awk \
  tools/review_lint_disposition.awk tools/change_log.sh tools/change_log_merge.sh \
  tools/change_log_entry.awk tools/change_log_tags.awk .greenfield-stamp; do
  check "happy path: $f is placed" test -f "$t1/$f"
done
# Load-bearing (files as placed): the same set of files as the template, plus the stamp.
want=$({
  cd "$here/template" && find . -type f ! -name .DS_Store
  echo ./.greenfield-stamp
} | sort)
got=$(cd "$t1" && find . -type f | sort)
check "happy path places exactly the template's files and the stamp" same "$want" "$got"
left=$(grep -rno '@@[A-Z_]*@@' "$t1" | head -n 5)
check "no token is left in the placed files: $left" test -z "$left"
check "name is written" grep -q '^# AGENTS.md — Sample Project$' "$t1/AGENTS.md"
check "owner is written literally" grep -qF "$owner" "$t1/docs/decisions.md"
check "date is written" grep -q '^date: 2026-01-31$' \
  "$t1/docs/decisions/d01-starts-from-greenfield-default.md"
check "output lists what was written" out_has '^wrote    docs/design.md$'
check "next steps say who runs each command" grep -q '|  run:|    git init .*|  the operator runs (an agent hands it over):|    make install-linters .*|  run:|    make change-log docs-lint llm-size-guard reviews-lint|  then, in a repository with no commit yet, commit the placed files unchanged: .*|  In a repository that already had commits, change-log reports CL04 until an entry|  records the placed files, and outside CI it may merge the upstream branch: see|  docs/greenfield/change-log.md, sections 4 and 6. Commit the entry with the files.|' <<<"${output//$nl/|}"

# Load-bearing (stamp): six lines of the stated form.
stamp="$t1/.greenfield-stamp"
version=$(head -n 1 "$here/VERSION")
check "stamp: six lines" same "$(wc -l <"$stamp" | tr -d ' ')" 6
check "stamp: version" grep -qx "greenfield_version = \"$version\"" "$stamp"
check "stamp: commit" grep -Eqx 'greenfield_commit = "([0-9a-f]{40}(\+dirty)?|unknown)"' "$stamp"
check "stamp: project" grep -qx 'project = "Sample Project"' "$stamp"
check "stamp: owner" grep -qxF "owner = \"$owner\"" "$stamp"
check "stamp: date" grep -qx 'date = "2026-01-31"' "$stamp"

# Load-bearing (stamp): a second run is refused, whatever the flags, and changes nothing.
before=$(listing "$t1")
run --target "$t1" --name "Sample Project" --owner Owner --keep-existing
check "second run is refused" exited 1
check "second run changes nothing" same "$before" "$(listing "$t1")"

# --- Tokens and special characters, small template ----------------------------
tpl=$(small_template basic)
t2="$work/basic"
run --target "$t2" --name "a.b_c-d 9" --owner "Owner" --date 2026-02-28 --template "$tpl"
check "small template exits 0" exited 0
check "tokens replaced in README" same "$(cat "$t2/README.md")" "# a.b_c-d 9
Owner: Owner on 2026-02-28"
check "version token replaced" grep -Eqx "v$version at ([0-9a-f]{40}(\\+dirty)?|unknown)" \
  "$t2/docs/sub/version.md"
check "other text is copied byte for byte" cmp -s "$tpl/Makefile" "$t2/Makefile"

# --- Never overwrite ----------------------------------------------------------
t3="$work/conflict"
mkdir -p "$t3"
printf 'mine\n' >"$t3/README.md"
before=$(listing "$t3")
run --target "$t3" --name P --owner O --template "$tpl"
check "conflict is refused" exited 1
check "conflict names the file" out_has '^  README.md$'
check "conflict writes nothing" same "$before" "$(listing "$t3")"

run --target "$t3" --name P --owner O --template "$tpl" --keep-existing
check "--keep-existing exits 0" exited 0
check "--keep-existing keeps the file" same "$(cat "$t3/README.md")" "mine"
check "--keep-existing places the rest" test -f "$t3/docs/sub/version.md"
check "--keep-existing writes the stamp" test -f "$t3/.greenfield-stamp"
check "--keep-existing reports it" out_has '^kept     README.md$'
check "--keep-existing says kept files are compared by hand" out_has '^Files marked "kept" were already present'

# --- .gitignore ----------------------------------------------------------------
t4="$work/gitignore"
mkdir -p "$t4"
printf 'node_modules/\n*.log\n' >"$t4/.gitignore"
run --target "$t4" --name P --owner O --template "$tpl"
check ".gitignore append exits 0" exited 0
expected='node_modules/
*.log

# >>> greenfield default rules >>>
/local/
# <<< greenfield default rules <<<'
check ".gitignore keeps its lines and gains the rules" same "$(cat "$t4/.gitignore")" "$expected"
t5="$work/gitignore-marked"
mkdir -p "$t5"
printf '# >>> greenfield default rules >>>\n/local/\n' >"$t5/.gitignore"
before=$(listing "$t5")
run --target "$t5" --name P --owner O --template "$tpl" --keep-existing
check "marked .gitignore is refused" exited 1
check "marked .gitignore: nothing written" same "$before" "$(listing "$t5")"

# --- Symbolic links in the target ---------------------------------------------
outside="$work/outside"
mkdir -p "$outside"

t6="$work/link-dir"
mkdir -p "$t6"
ln -s "$outside" "$t6/docs"
run --target "$t6" --name P --owner O --template "$tpl" --keep-existing
check "linked directory is refused" exited 1
check "linked directory: nothing written outside" empty_dir "$outside"
check "linked directory: nothing written inside" absent "$t6/README.md"
t7="$work/link-file"
mkdir -p "$t7"
ln -s "$outside/victim" "$t7/README.md" # dangling
run --target "$t7" --name P --owner O --template "$tpl" --keep-existing
check "dangling link is refused" exited 1
check "dangling link: the link's target is not created" absent "$outside/victim"
t8="$work/link-stamp"
mkdir -p "$t8"
ln -s "$outside/stamp" "$t8/.greenfield-stamp"
run --target "$t8" --name P --owner O --template "$tpl"
check "linked stamp is refused" exited 1
check "linked stamp: nothing written through the link" absent "$outside/stamp"
check "linked stamp: nothing written inside" absent "$t8/README.md"
t9="$work/not-a-dir"
printf 'x\n' >"$t9"
run --target "$t9" --name P --owner O --template "$tpl"
check "target that is a file is refused" exited 1

# --- Template checks ----------------------------------------------------------
tpl_link=$(small_template link)
ln -s /etc/hosts "$tpl_link/hosts"
run --target "$work/tpl-link" --name P --owner O --template "$tpl_link"
check "template with a link is refused" exited 1
check "template with a link: nothing created" absent "$work/tpl-link"
tpl_token=$(small_template token)
printf '@@SECRET_TOKEN@@\n' >"$tpl_token/docs/extra.md"
run --target "$work/tpl-token" --name P --owner O --template "$tpl_token"
check "template with an unknown token is refused" exited 1
check "template with an unknown token: nothing created" absent "$work/tpl-token"
tpl_ds=$(small_template dsstore)
printf 'junk\n' >"$tpl_ds/.DS_Store"
printf 'junk\n' >"$tpl_ds/docs/.DS_Store"
run --target "$work/tpl-ds" --name P --owner O --template "$tpl_ds"
check ".DS_Store: the run succeeds" exited 0
check ".DS_Store is not copied" test -z "$(find "$work/tpl-ds" -name .DS_Store)"

# A path with a newline or a tab in it could forge a line of the plan: the names below
# would read back as "write ../evil".
tpl_ctl=$(small_template control)
printf 'junk\n' >"$tpl_ctl/.DS_Store"
ctl_dir="$tpl_ctl/.DS_Store${nl}write${tab}.."
mkdir -p "$ctl_dir" && printf 'x\n' >"$ctl_dir/evil"
printf 'x\n' >"$work/evil" # what the forged line would copy
run --target "$work/ctl/t" --name P --owner O --template "$tpl_ctl"
check "template path with a control character is refused" exited 1
check "template path with a control character: nothing created" absent "$work/ctl"
tpl_stamp=$(small_template stamp)
printf 'x\n' >"$tpl_stamp/.greenfield-stamp"
run --target "$work/tpl-stamp" --name P --owner O --template "$tpl_stamp"
check "template holding a stamp is refused" exited 1
check "template holding a stamp: nothing created" absent "$work/tpl-stamp"
tpl_bin=$(small_template binary)
printf '\000 @@SECRET_TOKEN@@\n' >"$tpl_bin/blob.bin"
run --target "$work/tpl-bin" --name P --owner O --template "$tpl_bin"
check "unknown token in a binary file is refused" exited 1
check "unknown token in a binary file is named" out_has "unknown token: @@SECRET_TOKEN@@"
mkdir -p "$work/template.empty/docs"
run --target "$work/tpl-empty" --name P --owner O --template "$work/template.empty"
check "template with no files is refused" exited 1
check "template with no files: nothing created" absent "$work/tpl-empty"
tpl_dark=$(small_template dark)
chmod 000 "$tpl_dark/docs/sub"
run --target "$work/tpl-dark" --name P --owner O --template "$tpl_dark"
chmod 755 "$tpl_dark/docs/sub"
if [ "$(id -u)" -ne 0 ]; then
  check "template with an unreadable directory is an error" exited 2
  check "template with an unreadable directory: nothing created" absent "$work/tpl-dark"
fi

# --- Validation before sed: hostile values ------------------------------------
reject() { # reject <name> <args...>: exit 2, nothing created, nothing executed
  local label=$1; shift
  run --target "$work/hostile" --template "$tpl" "$@"
  if [ "$status" -ne 2 ]; then
    fail "$label: expected exit 2, got $status" "$output"
  elif [ -e "$work/hostile" ] || [ -e "$work/PWNED" ]; then
    fail "$label: something was created"
  else
    ok
  fi
}
e40=ëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëëë # 40 characters, 80 bytes
long_name=$(printf 'a%.0s' 1 2 3 4 5 6 7 8 9)
long_name="$long_name$long_name$long_name$long_name$long_name$long_name$long_name$long_name$long_name"
reject "name with command substitution" --name "\$(touch $work/PWNED)" --owner O
reject "name with a sed delimiter" --name 'a|b' --owner O
reject "name with an ampersand" --name 'a&b' --owner O
reject "name with a slash" --name '../x' --owner O
reject "name starting with a hyphen" --name '-x' --owner O
reject "name with a newline" --name "a
b" --owner O
reject "name of 81 characters" --name "$long_name" --owner O
reject "owner with an ampersand" --name P --owner 'A & B'
reject "owner with a sed delimiter" --name P --owner 'A | B'
reject "owner with a backslash" --name P --owner 'A\1B'
reject "owner with a double quote" --name P --owner 'A "B"'
reject "owner with a backtick" --name P --owner "A \`touch $work/PWNED\`"
reject "owner with a dollar" --name P --owner "\$(touch $work/PWNED)"
reject "owner with a token" --name P --owner 'A @@DATE@@'
reject "owner with a newline" --name P --owner "A
B"
reject "owner with a less-than sign" --name P --owner 'A <b>'
reject "owner with a tab" --name P --owner "A${tab}B"
reject "owner of 82 bytes in 41 characters" --name P --owner "${e40}ë"
reject "name that is not ASCII" --name 'Zoë' --owner O
reject "bad date" --name P --owner O --date 31-01-2026
reject "date with a sed delimiter" --name P --owner O --date '2026-01-31|x'
reject "missing --name" --owner O
reject "missing --owner" --name P
reject "unknown argument" --name P --owner O --frobnicate
reject "flag with no value" --name P --owner

run --target "$work/eighty" --name "${long_name%?}" --owner O --template "$tpl"
check "a name of 80 characters is accepted" exited 0
run --target "$work/eighty-bytes" --name P --owner "$e40" --template "$tpl"
check "an owner of 80 bytes in 40 characters is accepted" exited 0
run --target "$work/new${nl}line" --name P --owner O --template "$tpl"
check "a target with a newline in it is a usage error" exited 2
check "a target with a newline in it: nothing created" absent "$work/new"
run --name P --owner O
check "missing --target is a usage error" exited 2
run --help
check "--help exits 0" exited 0

# --- Dry run ------------------------------------------------------------------
run --target "$work/dry" --name P --owner O --template "$tpl" --dry-run
check "dry run exits 0" exited 0
check "dry run creates nothing" absent "$work/dry"
check "dry run prints the plan" out_has '^would write  README.md$'
check "dry run prints no next steps" test -z "$(printf '%s\n' "$output" | grep '^Next, in that directory:$')"
mkdir -p "$work/dry-conflict"
printf 'mine\n' >"$work/dry-conflict/README.md"
run --target "$work/dry-conflict" --name P --owner O --template "$tpl" --dry-run
check "dry run reports a conflict as a refusal" exited 1
mkdir -p "$work/dry-existing"
printf 'unrelated\n' >"$work/dry-existing/notes.txt"
before=$(listing "$work/dry-existing")
run --target "$work/dry-existing" --name P --owner O --template "$tpl" --dry-run
check "dry run against an existing target exits 0" exited 0
check "dry run against an existing target writes nothing" same "$before" "$(listing "$work/dry-existing")"
mkdir -p "$work/dry-mixed"
printf 'mine\n' | tee "$work/dry-mixed/README.md" >"$work/dry-mixed/.gitignore"
before=$(listing "$work/dry-mixed")
run --target "$work/dry-mixed" --name P --owner O --template "$tpl" --keep-existing --dry-run
check "dry run with files to keep and append exits 0" exited 0
check "dry run says what it would append" out_has '^would append .gitignore$'
check "dry run says what it would keep" out_has '^would keep   README.md$'
check "dry run says nothing was written" out_has '^dry run: nothing was written$'
check "dry run with files to keep and append writes nothing" same "$before" "$(listing "$work/dry-mixed")"

# --- Behavior 5: the other refusals -------------------------------------------
mkdir -p "$work/dir-at-file/README.md"
run --target "$work/dir-at-file" --name P --owner O --template "$tpl" --keep-existing
check "a directory where a file belongs is refused" exited 1
check "a directory where a file belongs: nothing written" absent "$work/dir-at-file/Makefile"
mkdir -p "$work/file-as-parent"
printf 'x\n' >"$work/file-as-parent/docs"
run --target "$work/file-as-parent" --name P --owner O --template "$tpl" --keep-existing
check "a file where a directory belongs is refused" exited 1
check "a file where a directory belongs: nothing written" absent "$work/file-as-parent/README.md"
mkdir -p "$work/two-conflicts"
printf 'mine\n' >"$work/two-conflicts/README.md"
printf 'mine\n' >"$work/two-conflicts/Makefile"
run --target "$work/two-conflicts" --name P --owner O --template "$tpl"
check "two conflicts are refused" exited 1
check "two conflicts: the first is listed" out_has '^  README.md$'
check "two conflicts: the second is listed" out_has '^  Makefile$'
mkdir -p "$work/both-kinds"
printf 'mine\n' >"$work/both-kinds/README.md"
ln -s "$outside" "$work/both-kinds/docs"
run --target "$work/both-kinds" --name P --owner O --template "$tpl"
check "a blocked path and a conflict are refused" exited 1
check "a blocked path and a conflict: the blocked path is listed" out_has '^  docs/sub/version.md$'
check "a blocked path and a conflict: the conflict is listed" out_has '^  README.md$'

# --- Behavior 6 and 8: a file that appears after the plan is not overwritten --
# A stand-in mkdir, first on PATH, creates $INJECT once its directory exists: that is
# after the plan is made and before the file is written.
shim="$work/shim"
mkdir -p "$shim"
real_mkdir=$(command -v mkdir)
# shellcheck disable=SC2016
{
  printf '#!/bin/sh\n'
  printf '[ -z "${DRAIN:-}" ] || cat >/dev/null\n'
  printf '"%s" "$@" || exit 1\n' "$real_mkdir"
  printf 'if [ ! -e "$INJECT" ] && [ -d "${INJECT%%/*}" ]; then printf "injected\\n" >"$INJECT"; fi\n'
} >"$shim/mkdir"
chmod +x "$shim/mkdir"

output=$(INJECT="$work/late-file/README.md" PATH="$shim:$PATH" bash "$init" \
  --target "$work/late-file" --name P --owner O --template "$tpl" 2>&1)
status=$?
check "a file that appears after the plan stops the run" exited 2
check "a file that appears after the plan is not overwritten" same "$(cat "$work/late-file/README.md")" "injected"
check "a run stopped part-way writes no stamp" absent "$work/late-file/.greenfield-stamp"

output=$(INJECT="$work/late-stamp/.greenfield-stamp" PATH="$shim:$PATH" bash "$init" \
  --target "$work/late-stamp" --name P --owner O --template "$tpl" 2>&1)
status=$?
check "a stamp that appears after the plan stops the run" exited 2
check "a stamp that appears after the plan is not overwritten" same "$(cat "$work/late-stamp/.greenfield-stamp")" "injected"
# A command that reads standard input in the write loop does not swallow the plan.
output=$(DRAIN=1 INJECT="$work/none/x" PATH="$shim:$PATH" bash "$init" \
  --target "$work/drained" --name P --owner O --template "$tpl" </dev/null 2>&1)
status=$?
check "a command that drains standard input: the run succeeds" exited 0
check "a command that drains standard input: every file is placed" same "$(cd "$tpl" && find . -type f | sort)" "$(cd "$work/drained" && find . -type f ! -name .greenfield-stamp | sort)"

# --- A target a command could misread is still only a path --------------------
odd="$work/odd"
home="$work/home"
mkdir -p "$odd/-P" "$home" "$outside/proj" "$odd/proj"
output=$(cd "$outside" && cd "$odd" && HOME="$home" bash "$init" \
  --target - --name P --owner O --template "$tpl" 2>&1)
status=$?
check "--target - exits 0" exited 0
check "--target - names a directory called -" test -f "$odd/-/README.md"
output=$(cd "$odd" && HOME="$home" bash "$init" --target -P --name P --owner O --template "$tpl" 2>&1)
status=$?
check "--target -P exits 0" exited 0
check "--target -P names the directory called -P" test -f "$odd/-P/README.md"
check "--target -P writes nothing in HOME" empty_dir "$home"
output=$(cd "$odd" && CDPATH="$outside" bash "$init" --target proj --name P --owner O --template "$tpl" 2>&1)
status=$?
check "an exported CDPATH: the run succeeds" exited 0
check "an exported CDPATH does not move a relative target" test -f "$odd/proj/README.md"
check "an exported CDPATH: nothing is written where it points" empty_dir "$outside/proj"
rmdir "$outside/proj"
mkdir -p "$work/real-target"
ln -s "$work/real-target" "$work/link-target"
run --target "$work/link-target" --name P --owner O --template "$tpl"
check "a target that is a link to a directory is followed" test -f "$work/real-target/README.md"

# --- Behavior 3: the version and the commit -----------------------------------
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
g() { git -c user.name=test -c user.email=test@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
kit="$work/kit"
mkdir -p "$kit"
cp "$init" "$kit/greenfield_init.sh"
cp -R "$tpl" "$kit/template"
printf '1.2.3\n' >"$kit/VERSION"
kit_run() { # kit_run <target name>: place with the copy of the script in $kit
  output=$(bash "$kit/greenfield_init.sh" --target "$work/$1" --name P --owner O 2>&1)
  status=$?
}
kit_run kit-plain
check "outside Git: the run succeeds" exited 0
check "outside Git: the version is read from VERSION" grep -qx 'greenfield_version = "1.2.3"' "$work/kit-plain/.greenfield-stamp"
check "outside Git: the commit is unknown" grep -qx 'greenfield_commit = "unknown"' "$work/kit-plain/.greenfield-stamp"

g -C "$kit" init -q
g -C "$kit" add -A
g -C "$kit" commit -q -m kit
kit_head=$(g -C "$kit" rev-parse HEAD)
kit_run kit-clean
check "a clean checkout: the commit is HEAD" grep -qx "greenfield_commit = \"$kit_head\"" "$work/kit-clean/.greenfield-stamp"
# Load-bearing (Git is only asked): a stale index entry is not refreshed by the run.
touch -t 202001010000 "$kit/VERSION"
index_before=$(cksum <"$kit/.git/index")
output=$(GIT_DIR="$work/elsewhere" GIT_INDEX_FILE="$work/elsewhere-index" bash "$kit/greenfield_init.sh" \
  --target "$work/kit-env" --name P --owner O 2>&1)
status=$?
check "an exported GIT_DIR: the commit is still this checkout's" grep -qx "greenfield_commit = \"$kit_head\"" "$work/kit-env/.greenfield-stamp"
check "the checkout's Git index is not rewritten" same "$index_before" "$(cksum <"$kit/.git/index")"
check "nothing is written where GIT_INDEX_FILE points" absent "$work/elsewhere-index"
mkdir -p "$kit/inner" && cp -R "$kit/greenfield_init.sh" "$kit/VERSION" "$kit/template" "$kit/inner/"
output=$(bash "$kit/inner/greenfield_init.sh" --target "$work/kit-inner" --name P --owner O 2>&1)
status=$?
check "a copy beneath a work tree does not take that tree's commit" grep -qx 'greenfield_commit = "unknown"' "$work/kit-inner/.greenfield-stamp"
rm -rf "$kit/inner"
printf 'x\n' >"$kit/untracked.txt"
kit_run kit-dirty
check "a changed checkout: the commit is marked dirty" grep -qx "greenfield_commit = \"$kit_head+dirty\"" "$work/kit-dirty/.greenfield-stamp"

printf 'one point two\n' >"$kit/VERSION"
kit_run kit-badversion
check "a malformed VERSION is an error" exited 2
check "a malformed VERSION: nothing created" absent "$work/kit-badversion"
chmod 000 "$kit/VERSION"
kit_run kit-noversion
chmod 644 "$kit/VERSION"
if [ "$(id -u)" -ne 0 ]; then
  check "an unreadable VERSION is an error" exited 2
  check "an unreadable VERSION is reported by the script" out_has '^greenfield_init: '
fi

# --- Capability boundary: nothing outside the target changes ------------------
# TMPDIR names a directory that does not exist: a run that needed a temporary file
# (a here-document, on bash before 5.1) would fail.
script_dir() {
  (cd "$here" && find . \( -name .git -o -name .gate-scratch \) -prune -o -type f -exec cksum {} + | sort)
}
tpl_before=$(listing "$tpl")
here_before=$(script_dir)
cwd_dir="$work/cwd"
mkdir -p "$cwd_dir"
output=$(cd "$cwd_dir" && TMPDIR="$work/no-such-tmp" bash "$init" \
  --target "$work/boundary" --name P --owner O --template "$tpl" 2>&1)
status=$?
check "the boundary run succeeds with no usable TMPDIR" exited 0
check "the template is not changed" same "$tpl_before" "$(listing "$tpl")"
check "the script's own directory is not changed" same "$here_before" "$(script_dir)"
check "the working directory is not written to" empty_dir "$cwd_dir"
check "no temporary directory was created" absent "$work/no-such-tmp"
# The marker line is the only place the script may hold "<<": no here-document.
check "the script holds no here-document" same "$(grep -c '<<' "$init")" 1
check "nothing was written outside the target" empty_dir "$outside"

printf 'greenfield_init_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
