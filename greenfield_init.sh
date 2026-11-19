#!/usr/bin/env bash
# greenfield_init.sh — place the greenfield default repository into a new project directory.
# Built against contract v4 (greenfield_init_contract.md). Writes only
# under --target; never overwrites a file; runs no command from the template or the
# target.
#
# No here-documents or here-strings are used: bash before 5.1 implements them with a
# temporary file, and this script declares that it writes none.

set -u
set -o pipefail
unset CDPATH
LC_ALL=C
export LC_ALL
# The greenfield commit is read from the repository this script is in, whatever the
# caller's environment says.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX

usage() {
  printf '%s\n' \
    'Usage: greenfield_init.sh --target DIR --name NAME --owner OWNER' \
    '                          [--date YYYY-MM-DD] [--template DIR]' \
    '                          [--keep-existing] [--dry-run]' \
    '       greenfield_init.sh -h | --help' \
    '' \
    'Copy the default repository (template/ beside this script) into DIR, replacing the' \
    'project name, owner, date, and the greenfield version and commit, and write' \
    'DIR/.greenfield-stamp.' \
    '' \
    '  --target DIR      the new project directory; created if absent' \
    '  --name NAME       project name: ASCII letters, digits, space, ".", "_", "-";' \
    '                    starts with a letter or digit; at most 80 bytes' \
    '  --owner OWNER     the person who owns the project; at most 80 bytes' \
    '  --date DATE       the date recorded in the documents (default: today)' \
    '  --template DIR    a template other than the one beside this script' \
    '  --keep-existing   where a file already exists in DIR, keep it and place the rest' \
    '  --dry-run         print what would be done and write nothing' \
    '' \
    'An existing .gitignore is never replaced: the default rules are appended to it.' \
    'A directory that already holds .greenfield-stamp is refused.' \
    '' \
    'Exit codes: 0 placed (or dry run clean), 1 refused, 2 bad usage or environment.'
}

die() {
  printf 'greenfield_init: %s\n' "$1" >&2
  exit 2
}

refuse() {
  printf 'greenfield_init: refused: %s\n' "$1" >&2
  exit 1
}

target=""
name=""
owner=""
date=""
template=""
keep=0
dry=0

need_value() {
  [ "$1" -ge 2 ] || die "$2 needs a value"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target) need_value $# "$1"; target=$2; shift 2 ;;
    --name) need_value $# "$1"; name=$2; shift 2 ;;
    --owner) need_value $# "$1"; owner=$2; shift 2 ;;
    --date) need_value $# "$1"; date=$2; shift 2 ;;
    --template) need_value $# "$1"; template=$2; shift 2 ;;
    --keep-existing) keep=1; shift ;;
    --dry-run) dry=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -n "$target" ] || die "--target is required"
[ -n "$name" ] || die "--name is required"
[ -n "$owner" ] || die "--owner is required"
case "$target" in
  *[[:cntrl:]]*) die "--target holds a control character" ;;
esac

tab=$(printf '\t')
nl='
'

# anchored <path>: the path, made unambiguous as a path. A relative path gains a leading
# ./ so that no command can take it for an option or for the `cd -` shorthand.
anchored() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf './%s' "$1" ;;
  esac
}

# physical <directory>: its absolute physical path, or failure. A path that is not one
# absolute line is refused.
physical() {
  local dir
  dir=$(cd "$(anchored "$1")" 2>/dev/null && pwd -P) || return 1
  case "$dir" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$dir" in
    *"$nl"*) return 1 ;;
  esac
  printf '%s' "$dir"
}

# --- Behavior 1: validate the values that are written into files. -----------

re_name='^[A-Za-z0-9][A-Za-z0-9 ._-]*$'
re_date='^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'
re_version='^[0-9]+\.[0-9]+\.[0-9]+$'
re_hash='^[0-9a-f]{40}$'

[ "${#name}" -le 80 ] || die "--name is longer than 80 bytes"
[[ $name =~ $re_name ]] ||
  die "--name may hold ASCII letters, digits, space, '.', '_', and '-', and starts with a letter or digit"

[ "${#owner}" -le 80 ] || die "--owner is longer than 80 bytes"
# shellcheck disable=SC1003
case "$owner" in
  *[[:cntrl:]]*) die "--owner holds a control character" ;;
  *'\'* | *'|'* | *'&'* | *'"'* | *'`'* | *'$'* | *'<'* | *'>'* | *'@@'*)
    die "--owner may not hold any of \\ | & \" \` \$ < > or @@" ;;
esac

if [ -z "$date" ]; then
  date=$(date +%Y-%m-%d) || die "could not read today's date"
fi
[[ $date =~ $re_date ]] || die "--date must be YYYY-MM-DD"

# --- Behavior 2: the template. ----------------------------------------------
here=$(physical "$(dirname "$0")") || die "cannot find this script's directory"
[ -n "$template" ] || template="$here/template"
[ -d "$(anchored "$template")" ] || die "no template directory: $template"
template=$(physical "$template") || die "cannot enter the template directory"

# find must finish cleanly: a directory it cannot read would make the copy incomplete.
odd=$(find "$template" ! -type f ! -type d -print 2>/dev/null) ||
  die "cannot read every directory of the template: $template"
odd=${odd%%"$nl"*}
[ -z "$odd" ] || refuse "the template holds something that is not a file or a directory: $odd"

known_tokens='@@PROJECT_NAME@@ @@OWNER@@ @@DATE@@ @@GREENFIELD_VERSION@@ @@GREENFIELD_COMMIT@@'
# Every file is checked before anything else is done: its path holds no control
# character (the plan below is kept as lines with tab-separated fields), it can be
# read, it is not the stamp this script writes itself, and it holds only known tokens.
while IFS= read -r -d '' file; do
  rel=${file#"$template"/}
  case "$rel" in
    *[[:cntrl:]]*) refuse "the template holds a path with a control character in it" ;;
    .DS_Store | */.DS_Store) continue ;;
    .greenfield-stamp) refuse "the template holds .greenfield-stamp, which this script writes itself" ;;
  esac
  [ -r "$file" ] || die "cannot read the template file: $rel"
  found_tokens=$(grep -ao '@@[A-Za-z0-9_]*@@' "$file") || [ $? -eq 1 ] ||
    die "cannot search the template file: $rel"
  for token in $found_tokens; do
    case " $known_tokens " in
      *" $token "*) ;;
      *) refuse "the template holds an unknown token: $token" ;;
    esac
  done
done < <(find "$template" -type f -print0)

# --- Behavior 3: the greenfield version and commit. -------------------------
[ -f "$here/VERSION" ] || die "no VERSION file beside this script"
version=""
[ -r "$here/VERSION" ] || die "cannot read the VERSION file beside this script"
IFS= read -r version <"$here/VERSION" || true
[[ $version =~ $re_version ]] || die "VERSION does not hold a version of the form N.N.N"

# Git is asked without optional locks and with no file-system monitor, so that asking
# changes nothing in the script's directory and starts no configured helper.
ask_git() {
  git --no-optional-locks -c core.fsmonitor=false -C "$here" "$@" 2>/dev/null
}
commit=unknown
if command -v git >/dev/null 2>&1 && [ "$(ask_git rev-parse --show-toplevel)" = "$here" ]; then
  head_commit=$(ask_git rev-parse HEAD) || head_commit=""
  if [[ $head_commit =~ $re_hash ]]; then
    commit=$head_commit
    if [ -n "$(ask_git status --porcelain)" ]; then
      commit="$commit+dirty"
    fi
  fi
fi

# --- Behavior 4: the target. ------------------------------------------------
target=$(anchored "$target")
if [ -e "$target" ] || [ -L "$target" ]; then
  [ -d "$target" ] || refuse "the target exists and is not a directory: $target"
  root=$(physical "$target") || die "cannot enter the target: $target"
else
  root=""
fi

if [ -n "$root" ] && { [ -e "$root/.greenfield-stamp" ] || [ -L "$root/.greenfield-stamp" ]; }; then
  refuse "the target already holds .greenfield-stamp; greenfield is placed once"
fi

marker='# >>> greenfield default rules >>>'
marker_end='# <<< greenfield default rules <<<'

# --- Behavior 5: plan every file before writing any. ------------------------
# plan lines: "<action><tab><relative path>"; action is write, append, or keep.
plan=""
planned=0
kept=0
conflicts=""
blocked=""

# under_real_dirs <relative path>: every parent that exists is a real directory.
under_real_dirs() {
  local rel=$1 dir=$root part rest
  [ -n "$root" ] || return 0
  rest=$rel
  while [ "$rest" != "${rest#*/}" ]; do
    part=${rest%%/*}
    rest=${rest#*/}
    dir="$dir/$part"
    if [ -L "$dir" ]; then return 1; fi
    if [ -e "$dir" ] && [ ! -d "$dir" ]; then return 1; fi
  done
  return 0
}

while IFS= read -r -d '' file; do
  rel=${file#"$template"/}
  case "$rel" in
    .DS_Store | */.DS_Store) continue ;;
  esac
  action="write"
  if ! under_real_dirs "$rel"; then
    blocked="${blocked}${rel}${nl}"
    continue
  fi
  dest="$root/$rel"
  if [ -z "$root" ]; then
    action="write"
  elif [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -f "$dest" ]; }; then
    blocked="${blocked}${rel}${nl}"
    continue
  elif [ -f "$dest" ]; then
    if [ "$rel" = ".gitignore" ]; then
      if grep -qxF "$marker" "$dest"; then
        blocked="${blocked}${rel}${nl}"
        continue
      fi
      action=append
    elif [ "$keep" -eq 1 ]; then
      action=keep
      kept=$((kept + 1))
    else
      conflicts="${conflicts}${rel}${nl}"
      continue
    fi
  fi
  plan="${plan}${action}${tab}${rel}${nl}"
  planned=$((planned + 1))
done < <(find "$template" -type f -print0 | sort -z)

if [ -n "$blocked" ]; then
  printf 'greenfield_init: refused: these paths in the target are symbolic links, are not regular files, already carry the greenfield marker, or lie under such a path; nothing was written:\n' >&2
  printf '%s' "$blocked" | sed 's/^/  /' >&2
fi
if [ -n "$conflicts" ]; then
  printf 'greenfield_init: refused: these files already exist in the target; nothing was written (use --keep-existing to keep them and place the rest):\n' >&2
  printf '%s' "$conflicts" | sed 's/^/  /' >&2
fi
if [ -n "$blocked" ] || [ -n "$conflicts" ]; then
  exit 1
fi
[ "$planned" -gt 0 ] || refuse "the template holds no files"

# --- Behavior 10: a dry run stops here. -------------------------------------
if [ "$dry" -eq 1 ]; then
  while IFS=$tab read -r action rel; do
    case "$action" in
      write) printf 'would write  %s\n' "$rel" ;;
      append) printf 'would append %s\n' "$rel" ;;
      keep) printf 'would keep   %s\n' "$rel" ;;
    esac
  done < <(printf '%s' "$plan")
  printf 'would write  .greenfield-stamp\n'
  printf 'dry run: nothing was written\n'
  exit 0
fi

# --- Behaviors 6 to 8: write. -----------------------------------------------
# The values were validated above to hold none of the characters sed treats
# specially in a replacement with the delimiter |.
render() {
  sed -e "s|@@PROJECT_NAME@@|$name|g" \
    -e "s|@@OWNER@@|$owner|g" \
    -e "s|@@DATE@@|$date|g" \
    -e "s|@@GREENFIELD_VERSION@@|$version|g" \
    -e "s|@@GREENFIELD_COMMIT@@|$commit|g" \
    "$1"
}

if [ -z "$root" ]; then
  mkdir -p "$target" || die "cannot create the target: $target"
  root=$(physical "$target") || die "cannot enter the target: $target"
fi

set -C # noclobber: a file that appeared since the plan was made is not overwritten
handled=0
# The plan is read on descriptor 3, so that no command in the loop can take it as its
# standard input and cut the placement short.
while IFS=$tab read -r action rel <&3; do
  dest="$root/$rel"
  case "$action" in
    write)
      mkdir -p "$(dirname "$dest")" || die "cannot create the directory for $rel"
      render "$template/$rel" >"$dest" || die "could not write $rel (it may have appeared since the run began); the target is partly placed"
      printf 'wrote    %s\n' "$rel"
      ;;
    append)
      { printf '\n%s\n' "$marker" && render "$template/$rel" && printf '%s\n' "$marker_end"; } >>"$dest" ||
        die "could not append to $rel; the target is partly placed"
      printf 'appended %s\n' "$rel"
      ;;
    keep)
      printf 'kept     %s\n' "$rel"
      ;;
    *) die "internal error: unknown action in the plan" ;;
  esac
  handled=$((handled + 1))
done 3< <(printf '%s' "$plan")

# The stamp says the placement is complete, so it is written only when every planned
# file was handled.
[ "$handled" -eq "$planned" ] ||
  die "placed $handled of $planned files; the target is partly placed and has no stamp"

{
  printf '# Written by greenfield_init.sh when this repository was created. Do not edit.\n'
  printf 'greenfield_version = "%s"\n' "$version"
  printf 'greenfield_commit = "%s"\n' "$commit"
  printf 'project = "%s"\n' "$name"
  printf 'owner = "%s"\n' "$owner"
  printf 'date = "%s"\n' "$date"
} >"$root/.greenfield-stamp" || die "could not write .greenfield-stamp; the files were placed and the target has no stamp"
printf 'wrote    .greenfield-stamp\n'

# --- Behavior 9: say what to do next. ---------------------------------------
printf '%s\n' \
  '' \
  "greenfield $version placed in $root" \
  '' \
  'Next, in that directory:' \
  '  run:' \
  '    git init                    (if it is not a repository yet)' \
  '  the operator runs (an agent hands it over):' \
  '    make install-linters        (if glossarian-check, glossarian-gather, or' \
  '                                llm-size-guard is not on PATH)' \
  '  run:' \
  '    make change-log docs-lint llm-size-guard reviews-lint' \
  '  then, in a repository with no commit yet, commit the placed files unchanged: the' \
  '  first commit of a new repository is the default repository as greenfield placed it.' \
  '  In a repository that already had commits, change-log reports CL04 until an entry' \
  '  records the placed files, and outside CI it may merge the upstream branch: see' \
  '  docs/greenfield/change-log.md, sections 4 and 6. Commit the entry with the files.' \
  '' \
  'The agent that works in the new repository starts at docs/greenfield/start-here.md.'
if [ "$kept" -gt 0 ]; then
  printf '%s\n' \
    '' \
    'Files marked "kept" were already present and were not replaced. Compare each' \
    'with the template and reconcile it by hand.'
fi
exit 0
