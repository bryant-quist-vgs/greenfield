#!/usr/bin/env bash
# review_lint.sh — check the review records and disposition files under reviews/.
# Built against contract v2. The contract and the tests of this tool are kept in the
# greenfield repository, under tools/, and not here. `make reviews-lint` runs it, and an
# agent may run that target. It reads files and asks Git questions. It
# writes nothing, temporary files included: it holds no here-document and no
# here-string, because bash before 5.1 implements both with a temporary file. Text from
# the files it checks is never executed.

set -u
set -o pipefail
unset CDPATH
export LC_ALL=C
# The repository is the one --repo names, whatever the caller's environment says.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX
export GIT_NO_LAZY_FETCH=1

usage() {
  printf '%s\n' \
    'Usage: review_lint.sh [--repo DIR]' \
    '       review_lint.sh -h | --help' \
    '' \
    'Check every file under DIR/reviews/ (default DIR: .) against the form in' \
    'docs/greenfield/adversarial-review.md. Prints one line for each violation:' \
    '  reviews/<file>:<line>: RL<nn> <message>' \
    '' \
    'Exit codes: 0 no violations, 1 violations, 2 anything that stops the check' \
    'from being made (bad usage, or a repository the check cannot read in full).'
}

die() {
  printf 'review_lint: %s\n' "$1" | tr -d '\000-\010\013-\037\177' >&2
  exit 2
}

repo=.
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || die "--repo needs a directory"
      repo=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is not on PATH"
command -v awk >/dev/null 2>&1 || die "awk is not on PATH"
case "$repo" in
  /*) ;;
  *) repo="./$repo" ;;
esac
[ -d "$repo" ] || die "not a directory: $repo"
root=$(cd "$repo" && pwd -P) || die "cannot enter: $repo"

# Every question to Git goes through here: no index refresh, no file-system monitor.
ask_git() { git --no-optional-locks -c core.fsmonitor=false -C "$root" "$@"; }

ask_git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  die "not inside a Git work tree: $repo"
if [ ! -d "$root/reviews" ] || [ -L "$root/reviews" ]; then
  die "no reviews/ directory in: $repo"
fi
ask_git ls-files --cached --others --exclude-standard -- reviews/ >/dev/null 2>&1 ||
  die "git could not list the files under reviews/"
# Git exits 0 when HEAD names a commit and 1 when it names none; any other exit is no
# answer, and RL09 must not be skipped on it. HEAD names no commit in a new repository,
# and also on an orphan branch or a damaged one, where a history exists and would go
# unread: only a repository with no reference at all, and no complaint from Git about
# one, is taken for new.
ask_git rev-parse -q --verify HEAD >/dev/null 2>&1
case $? in
  0) has_head=1 ;;
  1)
    refs=$(ask_git for-each-ref --count=1 2>&1) || die "git could not list the references"
    [ -z "$refs" ] ||
      die "HEAD names no commit, and Git printed something when asked for the references (a reference, or a warning): the history cannot be checked from this branch"
    has_head=0
    ;;
  *) die "git could not say whether the repository has a commit" ;;
esac
# A clone without its full history cannot answer RL03 and RL09, and must not look clean.
# Only the answer "false" lets the run go on: a Git that fails, or that does not know
# the question and prints something else, has not said that the history is whole.
shallow=$(ask_git rev-parse --is-shallow-repository 2>/dev/null) ||
  die "git could not say whether the clone is shallow"
case "$shallow" in
  false) ;;
  true) die "a shallow clone lacks the history the check needs; the operator fetches the full history (git fetch --unshallow)" ;;
  *) die "git did not say whether the clone is shallow (Git 2.15 or later answers)" ;;
esac
# A partial clone is marked in the configuration: a promisor remote, a partial-clone
# filter on a remote, or the extensions.partialclone setting. The setting is looked for
# by name, whatever its value. Git exits 0 when a setting matches and 1 when none does;
# any other exit is no answer.
ask_git config --get-regexp \
  '^(extensions\.partialclone|remote\..*\.(promisor|partialclonefilter))$' >/dev/null 2>&1
case $? in
  0) die "the Git configuration holds a partial-clone setting (extensions.partialclone, or promisor or partialclonefilter on a remote); a partial clone lacks objects the check needs" ;;
  1) ;;
  *) die "git could not read its configuration" ;;
esac

# The two parsers are awk programs beside this script. They print tab-separated lines:
# V (a violation), F (a finding), C (a commit to look up), P (a prior-findings row),
# B (a backlog file that must exist), X (a review that must judge a finding resolved),
# and E last (the parser reached the end of the file).
here=$(cd "$(dirname -- "$0")" && pwd -P) || die "cannot find this script's directory"
record_awk="$here/review_lint_record.awk"
disposition_awk="$here/review_lint_disposition.awk"
if [ ! -f "$record_awk" ] || [ ! -f "$disposition_awk" ]; then
  die "review_lint_record.awk and review_lint_disposition.awk must be beside this script"
fi

nl='
'
tab=$'\t'
zero=0000000000000000000000000000000000000000
out=""
count=0
add() {
  out="${out}$1${nl}"
  count=$((count + 1))
}

re_hash='^[0-9a-f]{40}$'
re_disposition='^R([0-9][0-9])-disposition\.md$'
re_record='^R([0-9][0-9])-([a-z0-9]+(-[a-z0-9]+)*)\.md$'
re_backlog='^backlog/R[0-9][0-9]-F[0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$'

commit_exists() {
  [[ $1 =~ $re_hash ]] || return 1
  ask_git cat-file -e "$1^{commit}" 2>/dev/null
}

# history <pathspec>: the raw changes of every commit reachable from HEAD, each merge
# against each of its parents. Lines of interest begin with a colon:
#   :<mode> <mode> <old blob> <new blob> <status><TAB><path>
# The -c settings pin what a repository's or a user's configuration could change.
history() {
  ask_git -c log.showRoot=true -c log.follow=false -c log.showSignature=false \
    -c log.diffMerges=separate log --full-history -m --raw --no-abbrev --no-renames \
    --no-color --relative --ignore-submodules=none --format=%H -- "$1" 2>/dev/null
}

# --- Behavior 1 and RL01: list and classify the files. ----------------------
records=""       # lines: "<NN> <path>"
record_nums=""   # lines: "<NN>"
dispositions=""  # lines: "<NN>"
listed=0
while IFS= read -r -d '' path; do
  case "$path" in
    *[!\ -~]*)
      add "${path//[! -~]/?}:1: RL01 a file name holds a character that is not printable ASCII"
      continue
      ;;
  esac
  if [ -L "$root/$path" ]; then
    add "$path:1: RL01 a symbolic link; files under reviews/ are regular files"
    continue
  fi
  # Tracked and missing from the working tree: RL09 reports it if it is a record the
  # history holds.
  [ -e "$root/$path" ] || continue
  if [ ! -f "$root/$path" ]; then
    add "${path%/}:1: RL01 not a regular file; files under reviews/ are regular files"
    continue
  fi
  name=${path#reviews/}
  case "$name" in
    */*)
      add "$path:1: RL01 files under reviews/ are not kept in subdirectories"
      continue
      ;;
    README.md | TEMPLATE-record.md | TEMPLATE-disposition.md) continue ;;
  esac
  if [[ $name =~ $re_disposition ]]; then
    dispositions="${dispositions}${BASH_REMATCH[1]}${nl}"
  elif [[ $name =~ $re_record ]]; then
    nn=${BASH_REMATCH[1]}
    slug=${BASH_REMATCH[2]}
    hyphens=${slug//[^-]/}
    if [ "${#hyphens}" -gt 5 ]; then
      add "$path:1: RL01 the slug of a record has at most six words"
    fi
    case "${nl}${record_nums}" in
      *"${nl}${nn}${nl}"*)
        add "$path:1: RL01 a second record numbered R${nn}"
        continue
        ;;
    esac
    record_nums="${record_nums}${nn}${nl}"
    records="${records}${nn} ${path}${nl}"
    listed=$((listed + 1))
  else
    add "$path:1: RL01 not a record (R<NN>-<slug>.md), a disposition file (R<NN>-disposition.md), README.md, or a TEMPLATE file"
  fi
done < <(ask_git ls-files -z --cached --others --exclude-standard -- reviews/)

records=$(printf '%s' "$records" | sort) || die "sort failed"

expected=1
while read -r nn path; do
  [ -n "$nn" ] || continue
  if [ "$((10#$nn))" -ne "$expected" ]; then
    add "$path:1: RL01 review numbers run from R01 without gaps; R$(printf '%02d' "$expected") is missing"
  fi
  expected=$((10#$nn + 1))
done < <(printf '%s\n' "$records")

while read -r nn; do
  [ -n "$nn" ] || continue
  case "${nl}${record_nums}" in
    *"${nl}${nn}${nl}"*) ;;
    *) add "reviews/R${nn}-disposition.md:1: RL01 a disposition file with no record R${nn}" ;;
  esac
done < <(printf '%s\n' "$dispositions")

# --- RL09: a record keeps the content it was first committed with. ----------
unchanged() { # <path of a record>
  local log_out blobs="" n=0 colon new worktree
  log_out=$(history "$1") || die "git log failed for $1"
  while read -r colon _ _ new _; do
    case "$colon" in
      :*) ;;
      "") continue ;;
      *)
        [[ $colon =~ $re_hash ]] && continue
        die "git log printed a line this script cannot read"
        ;;
    esac
    [[ $new =~ $re_hash ]] || die "git log printed a line this script cannot read"
    [ "$new" = "$zero" ] && continue
    case "${nl}${blobs}" in
      *"${nl}${new}${nl}"*) ;;
      *)
        blobs="${blobs}${new}${nl}"
        n=$((n + 1))
        ;;
    esac
  done < <(printf '%s\n' "$log_out")
  [ "$n" -gt 0 ] || return 0
  if [ "$n" -gt 1 ]; then
    add "$1:1: RL09 the record changed after it was committed ($n versions in the history)"
    return 0
  fi
  worktree=$(ask_git hash-object --no-filters -- "$1" 2>/dev/null) || die "git could not hash $1"
  if [ "${worktree}${nl}" != "$blobs" ]; then
    add "$1:1: RL09 the working copy differs from the committed record"
  fi
}

# gone_records: reports every record path the history holds that is not a regular file
# in the working tree.
gone_records() {
  local log_out seen="" rest path name
  log_out=$(history reviews/) || die "git log failed for reviews/"
  while IFS= read -r rest; do
    case "$rest" in
      :*"$tab"*) ;;
      "") continue ;;
      *)
        [[ $rest =~ $re_hash ]] && continue
        die "git log printed a line this script cannot read"
        ;;
    esac
    path=${rest#*"$tab"}
    name=${path#reviews/}
    [[ $path == reviews/* && $name =~ $re_record ]] || continue
    [[ $name =~ $re_disposition ]] && continue
    if [ -f "$root/$path" ] && [ ! -L "$root/$path" ]; then continue; fi
    case "${nl}${seen}" in
      *"${nl}${path}${nl}"*) continue ;;
    esac
    seen="${seen}${path}${nl}"
    add "$path:1: RL09 the history holds this record and it is gone; a record is never deleted or renamed"
  done < <(printf '%s\n' "$log_out")
}

# plain <path> <rule>: the file holds no control character but tab and line feed. A
# carriage return or a NUL would be read one way by awk and another by a renderer.
plain() {
  local raw clean
  raw=$(wc -c <"$root/$1") || die "cannot read $1"
  clean=$(tr -d '\000-\010\013-\037\177' <"$root/$1" | wc -c) || die "cannot read $1"
  [ "$((raw))" -eq "$((clean))" ] ||
    add "$1:1: $2 the file holds a control character other than tab and line feed"
}

# --- Pass 1: records (RL02 to RL06, RL09). ----------------------------------
all_findings=""  # lines: "<NN> <finding id>"
priors=""        # lines: "<NN> <line> <finding id> <result> <path>"
record_count=0
while read -r nn path; do
  [ -n "$nn" ] || continue
  record_count=$((record_count + 1))
  plain "$path" RL04
  ended=0
  # "$root" is absolute, so awk cannot take the operand for a variable assignment.
  parsed=$(awk -v nn="$nn" -f "$record_awk" "$root/$path") || die "awk failed on $path"
  while IFS=$tab read -r kind a b c; do
    case "$kind" in
      V) add "$path:$a: $b $c" ;;
      F) all_findings="${all_findings}${nn} ${b}${nl}" ;;
      C) commit_exists "$b" || add "$path:$a: RL03 Git has no commit $b" ;;
      P) priors="${priors}${nn} ${a} ${b} ${c} ${path}${nl}" ;;
      E) ended=1 ;;
      "") ;;
      *) die "the record parser printed a line this script cannot read" ;;
    esac
  done < <(printf '%s\n' "$parsed")
  [ "$ended" -eq 1 ] || die "the record parser did not finish $path"
  [ "$has_head" -eq 0 ] || unchanged "$path"
done < <(printf '%s\n' "$records")
[ "$record_count" -eq "$listed" ] || die "listed $listed records and read $record_count"
[ "$has_head" -eq 0 ] || gone_records

# --- RL06 across records: a prior finding exists in a lower-numbered record. -
while read -r nn line id _ path; do
  [ -n "$nn" ] || continue
  fnn=${id:1:2}
  case "${nl}${all_findings}" in
    *"${nl}${fnn} ${id}${nl}"*)
      if [ "$((10#$fnn))" -ge "$((10#$nn))" ]; then
        add "$path:$line: RL06 $id is not a finding of a lower-numbered record"
      fi
      ;;
    *) add "$path:$line: RL06 no record holds the finding $id" ;;
  esac
done < <(printf '%s\n' "$priors")

# --- Pass 2: disposition files (RL07, RL08). --------------------------------
paired=0
while read -r nn path; do
  [ -n "$nn" ] || continue
  paired=$((paired + 1))
  dpath="reviews/R${nn}-disposition.md"
  case "${nl}${dispositions}" in
    *"${nl}${nn}${nl}"*) ;;
    *)
      add "$path:1: RL07 the record has no disposition file $dpath"
      continue
      ;;
  esac
  ids=""
  while read -r fnn id; do
    [ "$fnn" = "$nn" ] && ids="${ids}${id} "
  done < <(printf '%s\n' "$all_findings")
  plain "$dpath" RL07
  ended=0
  parsed=$(awk -v nn="$nn" -v findings="$ids" -f "$disposition_awk" "$root/$dpath") ||
    die "awk failed on $dpath"
  while IFS=$tab read -r kind a b c; do
    case "$kind" in
      V) add "$dpath:$a: $b $c" ;;
      C) commit_exists "$b" || add "$dpath:$a: RL03 Git has no commit $b" ;;
      B)
        if ! [[ $b =~ $re_backlog ]] || [ -L "$root/$b" ] || [ ! -f "$root/$b" ]; then
          add "$dpath:$a: RL08 the backlog file named in Where does not exist"
        fi
        ;;
      X)
        judged=0
        while read -r pnn _ pid pres _; do
          if [ "$pnn" = "${c#R}" ] && [ "$pid" = "$b" ] && [ "$pres" = "resolved" ]; then
            judged=1
          fi
        done < <(printf '%s\n' "$priors")
        if [ "$judged" -eq 0 ]; then
          add "$dpath:$a: RL08 the review $c does not judge $b resolved under Prior findings"
        fi
        ;;
      E) ended=1 ;;
      "") ;;
      *) die "the disposition parser printed a line this script cannot read" ;;
    esac
  done < <(printf '%s\n' "$parsed")
  [ "$ended" -eq 1 ] || die "the disposition parser did not finish $dpath"
done < <(printf '%s\n' "$records")
[ "$paired" -eq "$listed" ] || die "listed $listed records and paired $paired"

# --- Behavior 13: report. ---------------------------------------------------
if [ "$count" -gt 0 ]; then
  printf '%s' "$out" | tr -d '\000-\010\013-\037\177'
  printf 'reviews-lint: %d record(s) checked, %d violation(s)\n' "$record_count" "$count"
  exit 1
fi
printf 'reviews-lint: %d record(s) checked, no violations\n' "$record_count"
exit 0
