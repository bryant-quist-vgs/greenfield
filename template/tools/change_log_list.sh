# shellcheck shell=bash disable=SC2034,SC2154
# change_log_list.sh — the tag file, the entries, and the generated list of change_log.sh.
# Built against contract v1; the contract and the tests are kept in the
# greenfield repository, under tools/. Sourced by change_log.sh for every verb, never run on its own: it uses that script's variables
# ($root, $LOG, $DIR, $TAGS, $baseline_tags, $nl, $tab, $re_entry, $re_tag, $entry_awk,
# $tags_awk, $parsed, $wrote, $tmp_file) and functions (ask_git, add, die, in_place,
# plain, parse, lines, time_ok). Only replace_log writes.

# --- CL06: the project's tags. --------------------------------------------------
project_tags=""  # " <tag> <tag>": the tags tags.md declares validly
read_tags() {
  local kind a b
  project_tags=""
  if [ -L "$root/$TAGS" ] || { [ -e "$root/$TAGS" ] && [ ! -f "$root/$TAGS" ]; }; then
    add "$TAGS" 1 "CL06 not a regular file; the project's tags are declared in a regular file"
    return 0
  fi
  if [ ! -e "$root/$TAGS" ]; then
    add "$TAGS" 1 "CL06 the file is missing; it declares the project's tags in a table with the header | Tag | Meaning |"
    return 0
  fi
  plain "$TAGS" CL06 || return 0
  parse "$tags_awk" "$TAGS" -v baseline="$baseline_tags"
  while IFS=$tab read -r kind a b; do
    case "$kind" in
      V) add "$TAGS" "$a" "CL06 $b" ;;
      G)
        [[ $a =~ $re_tag ]] || die "the tag parser printed a tag this script cannot read"
        project_tags="$project_tags $a"
        ;;
      E | "") ;;
      *) die "the tag parser printed a line this script cannot read" ;;
    esac
  done < <(printf '%s\n' "$parsed")
}

# --- CL01 and CL02: the entries. ------------------------------------------------
entries=""    # lines "<file name>": every entry whose name passes CL01
untracked=""  # lines "<file name>": those of them that Git does not track yet
listing=""    # lines "<file name><tab><title><tab><tags>": the entries the list shows
entry_count=0 found=0 listed=0
scan() {
  local path name kind a b kinds seen expected last
  entries="" untracked="" listing="" entry_count=0 found=0 listed=0
  in_place
  read_tags
  # Git lists the tracked files and then the untracked ones that are not ignored. Each
  # listing is asked for twice: once to count its names with Git's exit status in hand,
  # and once to read them. A listing that fails or stops short must never become an
  # empty or a partial list.
  # shellcheck disable=SC2086 # $kinds is split on purpose: the options of one listing
  for kinds in --cached "--others --exclude-standard"; do
    expected=$(ask_git ls-files -z $kinds -- "$DIR/" 2>/dev/null | tr -cd '\000' | wc -c) ||
      die "git could not list the files under $DIR/"
    seen=0 last=""
    while IFS= read -r -d '' path; do
      seen=$((seen + 1))
      # A path that is unmerged is listed once for each of its stages.
      [ "$path" = "$last" ] && continue
      last=$path
      [ "$path" = "$TAGS" ] && continue
      case "$path" in
        *[!\ -~]*)
          found=$((found + 1))
          add "$path" 1 "CL01 a file name holds a character that is not printable ASCII"
          continue
          ;;
      esac
      if [ -L "$root/$path" ]; then
        found=$((found + 1))
        add "$path" 1 "CL01 a symbolic link; an entry is a regular file"
        continue
      fi
      # Tracked and missing from the working tree: CL04 reports an entry that is gone.
      [ -e "$root/$path" ] || continue
      found=$((found + 1))
      if [ ! -f "$root/$path" ]; then
        add "${path%/}" 1 "CL01 not a regular file; an entry is a regular file"
        continue
      fi
      name=${path#"$DIR"/}
      case "$name" in
        */*)
          add "$path" 1 "CL01 entries are not kept in subdirectories"
          continue
          ;;
      esac
      if [[ $name =~ $re_entry ]] && time_ok "${BASH_REMATCH[1]}"; then
        entries="${entries}${name}${nl}"
        [ "$kinds" = --cached ] || untracked="${untracked}${name}${nl}"
      else
        add "$path" 1 "CL01 not tags.md and not an entry: <YYYY-MM-DD>-<hhmmss>-<slug>.md, a UTC date and time of day and a slug of 1 to 6 words of lowercase letters and digits joined by hyphens"
      fi
    done < <(ask_git ls-files -z $kinds -- "$DIR/" 2>/dev/null)
    [ "$seen" -eq "$((expected))" ] || die "git listed the files under $DIR/ two ways; nothing was written from the listing"
  done

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    entry_count=$((entry_count + 1))
    path="$DIR/$name"
    plain "$path" CL02 || continue
    parse "$entry_awk" "$path" -v name="${name%.md}" -v known="$baseline_tags$project_tags" \
      -v baseline="$baseline_tags"
    while IFS=$tab read -r kind a b; do
      case "$kind" in
        V) add "$path" "$a" "CL02 $b" ;;
        T)
          listing="${listing}${name}${tab}${a}${tab}${b}${nl}"
          listed=$((listed + 1))
          ;;
        E | "") ;;
        *) die "the entry parser printed a line this script cannot read" ;;
      esac
    done < <(printf '%s\n' "$parsed")
  done < <(printf '%s\n' "$entries")
  [ "$(lines "$entries")" -eq "$entry_count" ] || die "listed and read a different number of entries"
  listing=$(printf '%s' "$listing" | sort -r) || die "sort failed"
}

# --- The text of docs/change_log.md, from $listing. -----------------------------
log_text() {
  local name shown_title shown_tags day="" last=""
  # shellcheck disable=SC2016 # the backticks are Markdown, written literally
  printf '%s\n' '---' 'id: change-log' 'title: Change log' 'is_source_of_truth: false' \
    'derives_from: []' 'status: current' 'authority: >' \
    '  Generated by tools/change_log.sh from the entries under docs/change_log/. Never' \
    '  edited by hand: the next run of the tool overwrites an edit, and the change-log' \
    '  gate fails until it has.' \
    '---' '' '# Change log' '' \
    'This file is generated by `tools/change_log.sh` from the entries under `change_log/`,' \
    'one file for each change, newest first. It is not edited. The rules, and the meaning' \
    'of each baseline tag, are in [greenfield/change-log.md](greenfield/change-log.md). The' \
    'tags of this project are in [change_log/tags.md](change_log/tags.md).' ''
  if [ -z "$listing" ]; then
    printf 'No entries yet.\n'
    return 0
  fi
  while IFS=$tab read -r name shown_title shown_tags; do
    [ -n "$name" ] || continue
    day=${name:0:10}
    if [ "$day" != "$last" ]; then
      [ -z "$last" ] || printf '\n'
      printf '## %s\n\n' "$day"
      last=$day
    fi
    printf -- '- [%s](change_log/%s) (%s)\n' "$shown_title" "$name" "$shown_tags"
  done < <(printf '%s\n' "$listing")
}

# log_current: 0 when docs/change_log.md is what log_text prints, 1 when it is not.
log_current() {
  [ -f "$root/$LOG" ] || return 1
  log_text | cmp -s - "$root/$LOG"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) die "cannot compare $LOG with the generated text" ;;
  esac
}

# replace_log <command...>: what the command prints becomes docs/change_log.md. It is
# written to a temporary file beside the list, created only if no such file exists, and
# moved over the list. The trap of change_log.sh removes the temporary file when the
# run fails or is interrupted; a file that another run left is not this run's to remove.
replace_log() {
  local tmp="$root/$LOG.tmp.$$"
  (set -o noclobber && : >"$tmp") 2>/dev/null ||
    die "cannot create $LOG.tmp.$$ (remove it if a failed run left it)"
  tmp_file=$tmp
  if ! "$@" >"$tmp" || ! mv -f "$tmp" "$root/$LOG"; then die "cannot write $LOG"; fi
  tmp_file=""
}

# write_log: write the list, unless it is current.
log_written=0
write_log() {
  log_written=0
  log_current && return 0
  replace_log log_text
  log_written=1
  wrote="${wrote:+$wrote, and }written $LOG"
}

say_log() {
  if [ "$log_written" -eq 1 ]; then
    printf 'change-log: %s written, %d entry(ies) listed\n' "$LOG" "$listed"
  else
    printf 'change-log: %s is current, %d entry(ies) listed\n' "$LOG" "$listed"
  fi
  [ "$found" -eq "$listed" ] ||
    printf 'change-log: %d file(s) under %s/ are not listed; run make change-log to see why\n' \
      "$((found - listed))" "$DIR"
}
