# shellcheck shell=bash disable=SC2034,SC2154
# review_lint_test_lib.sh — the fixtures and helpers of review_lint_test.sh. Sourced by it,
# never run on its own: it expects $lint, the path of review_lint.sh, and it builds
# everything in a temporary directory that it removes on exit.

# A caller such as a Git hook may have set these; the tests build their own repositories.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX

work=$(mktemp -d "${TMPDIR:-/tmp}/review-lint-test.XXXXXX") || exit 2
trap 'chmod -R u+rw "$work" 2>/dev/null; rm -rf "$work"' EXIT

# Git must not read the configuration, hooks, or signing setup of the account that runs
# the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
g() { git -c user.name=test -c user.email=test@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null -C "$repo" "$@"; }
commit_all() { g add -A && g commit -q -m "$1"; }

passed=0 failed=0
ok() { passed=$((passed + 1)); }
fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$1"
  [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'
}

repo="" base=""
new_repo() {
  repo="$work/repo.$1"
  mkdir -p "$repo/reviews" "$repo/backlog"
  g init -q
  printf 'seed\n' >"$repo/seed.txt"
  commit_all seed
  base=$(g rev-parse HEAD)
}

f3='```' f4='````'
# record <NN> <slug> <scope> <base_commit> [<prior findings>]: a valid record, two findings.
record() {
  cat >"$repo/reviews/R$1-$2.md" <<EOF
---
id: review-r$1
title: "R$1. Goal and MVP"
is_source_of_truth: true
derives_from: [review-rubric]
status: current
review: R$1
form: 1
reviewed_commit: $base
base_commit: $4
scope: $3
passes: per-item, cross-item
date: 2026-01-31
reviewer: fresh agent session, vendor A model B
---

# R$1. Goal and MVP

## Scope

Read docs/design.md at the reviewed commit.

## Prior findings

${5:-None.}

## Findings

### R$1-F01 The MVP has no end-to-end scenario

${f3}finding
axis: completeness
also: verification-integrity
pass: per-item
location: docs/design.md:30
touches: test-harness, interface
$f3

#### Observation

Section 3 lists features and no scenario.

#### Evidence

${f4}text
# inside a fence: not a heading
  $f3
1. A quoted list item with an indented block: accepted inside a longer fence.
   ${f3}bash
   $f3
$f3
## Remarks
$f3
$f4

~~~
### R$1-F09 inside a tilde fence: not a finding
~~~

#### Consequence

Nothing shows the MVP works.

#### Resolved when

Each feature is reached by a scenario with an ID.

### R$1-F02 A term is used with two meanings

${f3}finding
axis: consistency
also: none
pass: cross-item
location: docs/design.md:12, docs/glossary.md:40
touches: local
$f3

#### Observation

The word is used for two things.

#### Evidence

Lines 12 and 40.

#### Consequence

A reader builds the wrong thing.

#### Resolved when

One meaning, defined once.

## Remarks

None.

## Verification and limits

- ${f3}make docs-lint${f3} exited 0: a code span at the start of a list item.
Ran make docs-lint: exit 0. Did not run the tests; there are none.
EOF
}

# disposition <NN>: a valid disposition file for record(), and the backlog file that its
# second row names.
disposition() {
  cat >"$repo/reviews/R$1-disposition.md" <<EOF
---
id: review-r$1-disposition
title: "R$1 disposition"
is_source_of_truth: true
derives_from: [review-r$1]
status: current
review: R$1
form: 1
---

# R$1 disposition

## Dispositions

| Finding | Blocks MVP | Expensive later | Disposition | State | Where |
|---|---|---|---|---|---|
| R$1-F01 | yes | yes | fix-now | open | - |
| R$1-F02 | no | no | later | open | \`backlog/R$1-F02-two-meanings.md\` |

## Reasons

### R$1-F01

Without a scenario the MVP cannot be shown working. Decided by the owner.

### R$1-F02

Wording only. Decided by the owner.
EOF
  printf 'finding file\n' >"$repo/backlog/R$1-F02-two-meanings.md"
}

valid() {
  new_repo "$1"
  record 01 goal-and-mvp design-increment none
  disposition 01
}

# A second review, scope fix, that judges R01-F01 resolved.
PRIOR='| Finding | Result | Evidence |
|---|---|---|
| R01-F01 | resolved | Section 3 now has scenario S-1. |'
fix_review() {
  valid "$1"
  record 02 fix-of-r01 fix "$base" "$PRIOR"
  disposition 02
}

REC=reviews/R01-goal-and-mvp.md DIS=reviews/R01-disposition.md FIX=reviews/R02-fix-of-r01.md
NOHASH=0123456789abcdef0123456789abcdef01234567

# edit <file> <sed expression>; row1, row2 <cells>: replace a disposition row of R01.
edit() { sed "$2" "$repo/$1" >"$repo/$1.tmp" && mv "$repo/$1.tmp" "$repo/$1"; }
row1() { edit "$DIS" "s#^| R01-F01 | .*#| R01-F01 | $1 |#"; }
row2() { edit "$DIS" "s#^| R01-F02 | .*#| R01-F02 | $1 |#"; }

output="" status=0
# run [<NAME=value>...]: lint $repo, with those variables added to the environment.
run() {
  output=$(env "$@" bash "$lint" --repo "$repo" 2>&1)
  status=$?
}
expect_clean() { # <label> [<NAME=value>...]
  local label=$1; shift
  run "$@"
  if [ "$status" -eq 0 ]; then ok; else fail "$label: expected no violations (exit $status)" "$output"; fi
}
# expect_rule <label> <RLnn> [<regex>]: exit 1, and a line citing the rule that matches.
expect_rule() {
  run
  if [ "$status" -ne 1 ]; then
    fail "$1: expected exit 1, got $status" "$output"
  elif ! printf '%s\n' "$output" | grep -E "^reviews/[^:]*:[0-9]+: $2 " | grep -Eq -- "${3:-.}"; then
    fail "$1: expected a $2 violation matching '${3:-.}'" "$output"
  else
    ok
  fi
}
# defect <slug> <rule> <file> <sed expression> <what> [<regex>]: plant one defect in a
# valid set of files (built by $setup) and require that rule to be reported.
setup=valid
defect() {
  $setup "$1"
  edit "$3" "$4"
  expect_rule "$2 $5" "$2" "${6:-}"
}
# rowdefect <slug> <rule> <row1|row2> <cells> <what> [<regex>]: the same, for a row.
# acted <slug> <rule> <what> <regex> <command...>: the same, for a command run in $repo.
rowdefect() {
  $setup "$1"
  "$3" "$4"
  expect_rule "$2 $5" "$2" "${6:-}"
}
acted() {
  $setup "$1"
  (cd "$repo" && "${@:5}")
  expect_rule "$2 $3" "$2" "$4"
}


# committed <slug>: valid, with a README so that reviews/ outlives its records, committed.
committed() {
  valid "$1"
  printf '# Reviews\n' >"$repo/reviews/README.md"
  commit_all "review R01"
}
