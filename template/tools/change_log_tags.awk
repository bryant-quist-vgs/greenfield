# change_log_tags.awk — read the project's tags from docs/change_log/tags.md for
# change_log.sh. Built against contract v1, which is kept with the tests in
# the greenfield repository, under tools/, and part of the unit it describes. It reads its one operand, writes only to standard output,
# runs no command, and opens no other file. Text from the file is compared with fixed
# patterns and never executed.
#
# Variable, set by change_log.sh:
#   baseline  the baseline tags, separated by spaces
#
# Output, tab-separated, one item to a line:
#   V <line> <message>   a departure from the form (rule CL06); the message is fixed text
#   G <tag>              a tag that a row declares validly
#   E                    last: the parser reached the end of the file
#
# The table is the lines from the header | Tag | Meaning | to the last line after it that
# starts with |. Every other line of the file is the project's prose and is not read.

function violation(message) { printf "V\t%d\t%s\n", (NR > 0 ? NR : 1), message }

function is_word(s) { return length(s) >= 1 && length(s) <= 30 && s ~ /^[a-z][a-z0-9-]*$/ }

function is_tag(s,    part, n) {
  n = split(s, part, ":")
  if (n == 1) return is_word(part[1])
  if (n == 2) return is_word(part[1]) && is_word(part[2])
  return 0
}

# cells(line): fills cell[] with the trimmed cells of a table line and returns their
# number, or -1 when the line does not start and end with |.
function cells(line,    n, i) {
  sub(/[ \t]+$/, "", line)
  if (length(line) < 2 || substr(line, 1, 1) != "|" || substr(line, length(line), 1) != "|") return -1
  n = split(substr(line, 2, length(line) - 2), cell, "[|]")
  for (i = 1; i <= n; i++) {
    sub(/^[ \t]+/, "", cell[i])
    sub(/[ \t]+$/, "", cell[i])
  }
  return n
}

function row(    n, tag) {
  n = cells($0)
  if (n == -1) { violation("a table row starts and ends with |"); return }
  if (n != 2) { violation("a table row has two cells: the tag in backticks, and its meaning"); return }
  tag = substr(cell[1], 2, length(cell[1]) - 2)
  if (cell[1] !~ /^`[^`]*`$/ || !is_tag(tag)) {
    violation("the first cell is one tag in backticks: a word, or namespace:word, each a lowercase letter then up to 29 lowercase letters, digits, and hyphens")
    return
  }
  if (cell[2] == "") { violation("the second cell, the meaning of the tag, is empty"); return }
  if (tag in is_baseline) { violation("the row declares a baseline tag; the baseline tags are fixed and are not declared here"); return }
  if (tag in declared) { violation("the tag is declared a second time"); return }
  declared[tag] = 1
  printf "G\t%s\n", tag
}

BEGIN {
  n_base = split(baseline, list, " ")
  for (i = 1; i <= n_base; i++) is_baseline[list[i]] = 1
  # state: 0 outside the table, 1 after its header, 2 in its rows, 3 in a second table.
  state = 0; headers = 0
}

state == 1 {
  state = 2
  if (cells($0) == 2 && cell[1] ~ /^:?-+:?$/ && cell[2] ~ /^:?-+:?$/) next
  violation("the line after the table header must be the separator row |---|---|")
  state = 0
}
state == 2 && /^\|/ { row(); next }
state == 3 && /^\|/ { next }
{
  state = 0
  if (cells($0) == 2 && cell[1] == "Tag" && cell[2] == "Meaning") {
    headers++
    if (headers == 1) state = 1
    else {
      violation("a second table with the header | Tag | Meaning |; the file holds one")
      state = 3
    }
  }
}

END {
  if (state == 1) violation("the table header is the last line; the separator row |---|---| is missing")
  if (headers == 0) violation("no table with the header | Tag | Meaning |")
  print "E"
}
