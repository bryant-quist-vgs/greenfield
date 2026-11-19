# shellcheck shell=bash disable=SC2034,SC2154
# change_log_new.sh — the verb `new` of change_log.sh: create one entry, then regenerate
# the list. Built against contract v1; the contract and the tests are kept
# in the greenfield repository, under tools/. Sourced by change_log.sh for `new`, never run on its own: it uses that script's variables ($root,
# $title, $tags_arg, $at, $DIR, $TAGS, $baseline_tags, $project_tags, $entries, $nl,
# $tab, $re_tag, $re_stamp, $entry_awk, $parsed, $out, $count, $wrote, $partial) and
# functions (die, read_tags, time_ok, lines, scan, write_log, say_log).

stamp="" slug="" tag_list=""
entry_text() {
  printf '%s\n' '---' "id: change-$stamp-$slug" "title: \"$title\"" 'is_source_of_truth: true' \
    'derives_from: []' 'status: current' "date: ${stamp:0:10}" "tags: [$tag_list]" '---' '' \
    "# $title" '' '## What changed' '' '<what changed, in one or more lines>' '' '## Why' '' \
    '<why the change was made, in one or more lines>'
}

do_new() {
  local clean words word n=0 base_seen=0 sorted kind b path
  clean=$(printf '%s' "$title$tags_arg" | tr -d '\000-\037\177') || die "tr failed"
  [ "$clean" = "$title$tags_arg" ] || die "--title and --tags are each one line with no control character"
  [ "${#title}" -le 100 ] || die "--title is longer than 100 bytes"
  case "$title" in
    " "* | *" ") die "--title starts or ends with a space" ;;
    *[\"\\\`\[\]\<\>\|]*) die '--title holds one of " \ ` [ ] < > |' ;;
  esac

  read_tags
  set -f
  # shellcheck disable=SC2086 # split on purpose: tags are separated by spaces or commas
  set -- ${tags_arg//,/ }
  set +f
  if [ $# -lt 1 ] || [ $# -gt 4 ]; then die "--tags takes 1 to 4 tags"; fi
  for word in "$@"; do
    n=$((n + 1))
    [[ $word =~ $re_tag ]] ||
      die "--tags: tag $n is not a tag (a word, or namespace:word, each a lowercase letter then up to 29 lowercase letters, digits, and hyphens)"
    case " $baseline_tags " in *" $word "*) base_seen=1 ;; esac
    case " $baseline_tags$project_tags " in
      *" $word "*) ;;
      *) die "--tags: $word is not a baseline tag and is not declared in $TAGS; the baseline tags are: $baseline_tags" ;;
    esac
  done
  [ "$base_seen" -eq 1 ] || die "--tags: at least one tag is a baseline tag: $baseline_tags"
  sorted=$(printf '%s\n' "$@" | sort -u) || die "sort failed"
  [ "$(lines "$sorted$nl")" -eq $# ] || die "--tags names a tag twice"
  tag_list=${sorted//"$nl"/, }

  if [ -n "$at" ]; then stamp=$at; else stamp=$(date -u +%Y-%m-%d-%H%M%S) || die "date failed"; fi
  if ! [[ $stamp =~ $re_stamp ]] || ! time_ok "${BASH_REMATCH[1]}"; then
    die "the date and time must be YYYY-MM-DD-hhmmss, a time of day (--at, or the clock)"
  fi
  # shellcheck disable=SC2018,SC2019 # under LC_ALL=C these ranges are the ASCII letters
  words=$(printf '%s' "$title" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' ' ') || die "tr failed"
  n=0
  set -f
  # shellcheck disable=SC2086 # split on purpose: the words of the title
  set -- $words
  set +f
  for word in "$@"; do
    [ "$n" -lt 6 ] || break
    slug="${slug:+$slug-}$word"
    n=$((n + 1))
  done
  [ -n "$slug" ] || slug=change
  path="$DIR/$stamp-$slug.md"

  # The entry that would be written goes through the parser first. Its two placeholder
  # lines are the only thing the parser may report.
  parsed=$(entry_text | awk -v name="$stamp-$slug" -v known="$baseline_tags$project_tags" \
    -v baseline="$baseline_tags" -f "$entry_awk") || die "awk failed on the new entry"
  [ "${parsed##*"$nl"}" = E ] || die "the parser did not finish the new entry"
  n=0
  while IFS=$tab read -r kind _ b; do
    case "$kind:$b" in
      V:"an unfilled placeholder"*) n=$((n + 1)) ;;
      V:*) die "the entry would not pass the check: $b" ;;
    esac
  done < <(printf '%s\n' "$parsed")
  [ "$n" -eq 2 ] || die "the entry would not pass the check"
  if [ -e "$root/$path" ] || [ -L "$root/$path" ]; then
    die "the entry exists and is never overwritten: $path; edit it, or give another title"
  fi

  if [ ! -d "$root/$DIR" ]; then
    mkdir "$root/$DIR" || die "cannot create $DIR"
    wrote="created $DIR"
  fi
  # Created only if nothing of that name exists, a dangling link included; then written.
  # If the write fails, the trap of change_log.sh removes what this run created.
  (set -o noclobber && : >"$root/$path") 2>/dev/null ||
    die "cannot create $path (an entry is never overwritten)"
  partial="$root/$path"
  entry_text >"$root/$path" || die "cannot write $path; the file this run created is removed"
  partial=""
  wrote="${wrote:+$wrote, and }created $path"
  out="" count=0
  scan
  case "${nl}${entries}" in
    *"${nl}$stamp-$slug.md${nl}"*) ;;
    *) die "Git does not list the new entry; is $DIR/ ignored?" ;;
  esac
  write_log
  printf '%s\n' "$path"
  printf 'change-log: entry created; replace the placeholder line under "## What changed" and the one under "## Why"\n'
  say_log
}

