# change_log_entry.awk — parse one change log entry for change_log.sh.
# Built against contract v1, which is kept with the tests in the greenfield
# repository, under tools/, and part of the unit it describes. It reads its one input (a file operand, or standard input), writes only to
# standard output, runs no command, and opens no other file. Text from the entry is
# compared with fixed patterns and never executed.
#
# Variables, set by change_log.sh:
#   name      the file name without .md, already matched against the name pattern
#   known     the tags an entry may carry, separated by spaces
#   baseline  the baseline tags, separated by spaces
#
# Output, tab-separated, one item to a line:
#   V <line> <message>   a departure from the form (rule CL02); the message is fixed text
#   T <title> <tags>     the title and the tags as the generated list shows them; printed
#                        only when the title line and the tags line can both be read
#   E                    last: the parser reached the end of the entry

function violation(message) { printf "V\t%d\t%s\n", (NR > 0 ? NR : 1), message }

function is_word(s) { return length(s) >= 1 && length(s) <= 30 && s ~ /^[a-z][a-z0-9-]*$/ }

function is_tag(s,    part, n) {
  n = split(s, part, ":")
  if (n == 1) return is_word(part[1])
  if (n == 2) return is_word(part[1]) && is_word(part[2])
  return 0
}

function real_date(d,    y, m, day, last) {
  y = substr(d, 1, 4) + 0
  m = substr(d, 6, 2) + 0
  day = substr(d, 9, 2) + 0
  if (m < 1 || m > 12 || day < 1) return 0
  last = 31
  if (m == 4 || m == 6 || m == 9 || m == 11) last = 30
  if (m == 2) last = (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28
  return day <= last
}

# The title is 1 to 100 bytes with no space at either end, no tab, and none of the
# characters that would let it end the link, the quoted value, or the line it is put in.
function title_fits(t) {
  if (length(t) < 1 || length(t) > 100) return 0
  if (substr(t, 1, 1) == " " || substr(t, length(t), 1) == " ") return 0
  if (index(t, "\t") || index(t, "\"") || index(t, "\\") || index(t, "`")) return 0
  if (index(t, "[") || index(t, "]") || index(t, "<") || index(t, ">") || index(t, "|")) return 0
  return 1
}

function read_tags(line,    inner, tag, n, i, shaped, base_seen) {
  if (line !~ /^tags: \[.*\]$/) {
    violation("front matter line 8 must be tags: [<tag>, <tag>], with 1 to 4 tags")
    return
  }
  inner = substr(line, 8, length(line) - 8)
  n = split(inner, tag, ", ")
  if (n < 1 || n > 4) violation("tags holds 1 to 4 tags, separated by a comma and a space")
  shaped = (n >= 1)
  base_seen = 0
  for (i = 1; i <= n; i++) {
    if (!is_tag(tag[i])) {
      violation("tag " i " is not a tag: a word, or namespace:word, each a lowercase letter then up to 29 lowercase letters, digits, and hyphens")
      shaped = 0
      continue
    }
    if (!(tag[i] in is_known))
      violation("tag " i " is not a baseline tag and is not declared in docs/change_log/tags.md")
    if (tag[i] in is_baseline) base_seen = 1
    if (i > 1 && (tag[i - 1] "") == (tag[i] ""))
      violation("tag " i " repeats tag " (i - 1))
    else if (i > 1 && is_tag(tag[i - 1]) && (tag[i - 1] "") > (tag[i] ""))
      violation("the tags are in ascending byte order; tag " i " sorts before tag " (i - 1))
    tags_shown = tags_shown (i > 1 ? ", " : "") "`" tag[i] "`"
  }
  if (shaped && !base_seen) violation("at least one tag is a baseline tag")
  tags_ok = shaped
}

BEGIN {
  n_known = split(known, list, " ")
  for (i = 1; i <= n_known; i++) is_known[list[i]] = 1
  n_base = split(baseline, list, " ")
  for (i = 1; i <= n_base; i++) is_baseline[list[i]] = 1
  day = substr(name, 1, 10)
  want[2] = "id: change-" name
  want[4] = "is_source_of_truth: true"
  want[5] = "derives_from: []"
  want[6] = "status: current"
  want[7] = "date: " day
  title_ok = 0; tags_ok = 0; tags_shown = ""
  # state: 0 before the # heading, 1 after it, 2 in "What changed", 3 in "Why".
  state = 0; content = 0; stray = 0
}

# --- Front matter: lines 1 to 9. ---------------------------------------------
NR == 1 || NR == 9 {
  if ($0 != "---") violation("line " NR " must be ---; the front matter is lines 1 to 9")
  next
}
NR == 3 {
  if ($0 ~ /^title: ".*"$/ && title_fits(substr($0, 9, length($0) - 9))) {
    title = substr($0, 9, length($0) - 9)
    title_ok = 1
  } else
    violation("front matter line 3 must be title: \"<title>\"; a title is 1 to 100 bytes with no space at either end, no tab, no backtick, and none of \" \\ [ ] < > |")
  next
}
NR == 8 { read_tags($0); next }
NR < 9 {
  if ($0 != want[NR]) {
    if (NR == 2) violation("front matter line 2 must be id: change-<the file name without .md>")
    else if (NR == 7) violation("front matter line 7 must be date: <the date in the file name>")
    else violation("front matter line " NR " must be " want[NR])
  }
  if (NR == 7 && !real_date(day)) violation("the date in the file name is not a calendar date")
  next
}

# --- Body: one # heading, then the two ## sections. ---------------------------
/^[ \t]*$/ { next }
/^[ \t]+#+([ \t]|$)/ { violation("a heading starts in column 1"); next }
/^[ \t]*((>|[-*+]|[0-9]+[.)])[ \t]*)+#+([ \t]|$)/ {
  violation("a heading inside a quote or a list item; an entry has one # heading and two ## headings")
  next
}
/^[ \t]*<[^<>]*>[ \t]*$/ {
  violation("an unfilled placeholder; replace the line with text")
  if (state >= 2) content++
  next
}
/^[ \t]*</ { violation("a line starts with <; raw HTML is not part of an entry"); next }
/^[ \t]*(=+|-+)[ \t]*$/ {
  violation("a line of only = or only -, which a renderer reads as a heading underline or a rule")
  next
}
$0 == "## What changed" {
  if (state == 0) violation("expected the heading # <title> before this one")
  else if (state > 1) violation("## What changed appears once, before ## Why")
  state = 2; content = 0
  next
}
$0 == "## Why" {
  if (state != 2) violation("## Why appears once, after ## What changed")
  else if (content == 0) violation("## What changed is empty")
  state = 3; content = 0
  next
}
/^#+([ \t]|$)/ {
  if (state == 0 && $0 ~ /^# /) {
    if (!title_ok || $0 != "# " title) violation("the # heading must be the title of the front matter")
    state = 1
  } else
    violation("a heading the form does not have; an entry has # <title>, ## What changed, and ## Why")
  next
}
{
  if (state >= 2) content++
  else if (!stray) {
    violation("text outside the two sections; an entry holds text only under ## What changed and ## Why")
    stray = 1
  }
}

END {
  if (NR < 9) violation("the front matter is incomplete; it is lines 1 to 9")
  else {
    if (state == 0) violation("the heading # <title> is missing")
    if (state <= 1) violation("the section ## What changed is missing")
    if (state == 2 && content == 0) violation("## What changed is empty")
    if (state <= 2) violation("the section ## Why is missing")
    if (state == 3 && content == 0) violation("## Why is empty")
  }
  if (title_ok && tags_ok) printf "T\t%s\t%s\n", title, tags_shown
  print "E"
}
