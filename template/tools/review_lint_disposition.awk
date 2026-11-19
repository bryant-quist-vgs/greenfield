# review_lint_disposition.awk — the disposition parser of review_lint.sh.
# Built against contract v2, which is kept with the tests in the greenfield repository,
# under tools/.
# review_lint.sh runs it on one disposition file, with the number from the file name
# and the finding IDs the record parser printed for the record of that number:
#   awk -v nn=<NN> -v findings="<the finding IDs, separated by spaces>" \
#       -f review_lint_disposition.awk <absolute path of reviews/R<NN>-disposition.md>
# Prints tab-separated lines and nothing else:
#   V <line> <rule> <message>        a violation
#   C <line> <hash>                  a commit to look up
#   B <line> <path>                  a backlog file that must exist
#   X <line> <finding id> <review>   a review that must judge the finding resolved
#   E <lines read>                   the last line: the file was read to its end
# Messages are fixed text: nothing read from the file is printed except a finding ID, a
# hash, a review number, or a backlog path that has already been checked against its
# pattern, and a disposition or a state that is one of the allowed values.
function viol(line, rule, msg) { printf "V\t%d\t%s\t%s\n", line, rule, msg }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function ishash(s) { return length(s) == 40 && s !~ /[^0-9a-f]/ }
function unfilled(s) { return s ~ /^<[^<>]+>$/ }
function inlist(list, x) {
  return x != "" && index(x, " ") == 0 && index(" " list " ", " " x " ") > 0
}
# Fences as in review_lint_record.awk: opened in column 1 by three or more backticks or
# tildes, closed by a line of at least as many of the same character, with nothing after
# them but spaces or tabs.
function fence_open(line,    n, c) {
  c = substr(line, 1, 1)
  if (c != "`" && c != "~") return 0
  n = 0
  while (substr(line, n + 1, 1) == c) n++
  if (n < 3) return 0
  if (c == "`" && index(substr(line, n + 1), "`") > 0) return 0
  fch = c
  return n
}
function fence_close(line,    n) {
  n = 0
  while (substr(line, n + 1, 1) == fch) n++
  return n >= flen && substr(line, n + 1) ~ /^[ \t]*$/
}
# As in review_lint_record.awk: structure inside a quote or a list item; table rows.
function contained(line,    n, s) {
  s = line; n = 0
  while (1) {
    sub(/^[ \t]+/, "", s)
    if (s ~ /^>/) { s = substr(s, 2); n++ }
    else if (s ~ /^[-*+]([ \t]|$)/) { s = substr(s, 2); n++ }
    else if (s ~ /^[0-9]+[.)]([ \t]|$)/) { sub(/^[0-9]+[.)]/, "", s); n++ }
    else break
  }
  # A backtick run with a backtick after it is a code span, not a fence.
  return n > 0 && s ~ /^(#+([ \t]|$)|~~~|```+[^`]*$|=+[ \t]*$|-+[ \t]*$)/
}
function norm(line,    n, c, i, s) {
  sub(/[ \t]+$/, "", line)
  if (line !~ /^\|.*\|$/) return ""
  n = split(line, c, "|"); s = "|"
  for (i = 2; i < n; i++) s = s " " trim(c[i]) " |"
  return s
}
function is_sep(line, want,    n, c, i) {
  sub(/[ \t]+$/, "", line)
  if (line !~ /^\|.*\|$/) return 0
  n = split(line, c, "|")
  if (n - 2 != want) return 0
  for (i = 2; i < n; i++) if (trim(c[i]) !~ /^:?-+:?$/) return 0
  return 1
}
function end_table(    i) {
  if (tn < 2) viol(NR, "RL07", "the dispositions table is missing its header or separator row")
  for (i = rows + 1; i <= nf; i++) viol(NR, "RL08", "no row for the finding " fid[i])
}
function end_reason() {
  if (ri > 0 && r_n == 0) viol(r_line, "RL08", "the reason is empty")
}
function table_line(line,    n, c, i, f, b, e, d, s, w, nt, t, tok, hash, rev, bl, okstate) {
  tn++
  if (tn == 1) {
    if (norm(line) != header) viol(NR, "RL07", "expected the table header " header)
    return
  }
  if (tn == 2) {
    if (!is_sep(line, 6)) viol(NR, "RL07", "expected the separator row |---|---|---|---|---|---|")
    return
  }
  rows++
  if (line !~ /^\|.*\|$/) { viol(NR, "RL08", "not a table row"); return }
  n = split(line, c, "|")
  if (n < 8) { viol(NR, "RL08", "a row has six cells"); return }
  f = trim(c[2]); b = trim(c[3]); e = trim(c[4]); d = trim(c[5]); s = trim(c[6]); w = ""
  for (i = 7; i < n; i++) w = w (i > 7 ? "|" : "") c[i]
  w = trim(w)
  if (rows > nf) { viol(NR, "RL08", "a row for something that is not a finding of the record"); return }
  if (f != fid[rows]) { viol(NR, "RL08", "expected the row for " fid[rows] " here"); return }
  if (unfilled(b) || unfilled(e) || unfilled(d) || unfilled(s) || unfilled(w)) {
    viol(NR, "RL08", "an unfilled placeholder"); return
  }
  if (b != "yes" && b != "no") viol(NR, "RL08", "Blocks MVP must be yes or no")
  if (e != "yes" && e != "no") viol(NR, "RL08", "Expensive later must be yes or no")
  if (!inlist("fix-now later declined", d)) { viol(NR, "RL08", "Disposition must be fix-now, later, or declined"); return }
  if (!inlist("open fixed verified closed", s)) { viol(NR, "RL08", "State must be open, fixed, verified, or closed"); return }
  if (d == "later" && (b != "no" || e != "no"))
    viol(NR, "RL08", "later is allowed only when Blocks MVP and Expensive later are both no")
  okstate = 1
  if (d == "fix-now" && s == "closed") okstate = 0
  if (d == "declined" && s != "closed") okstate = 0
  if (!okstate) { viol(NR, "RL08", "the state " s " is not allowed for the disposition " d); return }
  hash = ""; rev = ""; bl = ""
  nt = split(w, t, /[ \t]+/)
  for (i = 1; i <= nt; i++) {
    tok = t[i]
    gsub(/^[`(]+/, "", tok); gsub(/[`).,;:]+$/, "", tok)
    if (hash == "" && ishash(tok)) hash = tok
    if (rev == "" && tok ~ /^R[0-9][0-9]$/) rev = tok
    if (bl == "" && tok ~ /^backlog\/R[0-9][0-9]-F[0-9][0-9]-[a-z0-9-]+\.md$/ &&
        index(tok, "backlog/" f "-") == 1) bl = tok
  }
  if (s == "open" && d == "fix-now" && w != "-") viol(NR, "RL08", "Where must be - for an open fix-now finding")
  if (s == "open" && d == "later") {
    if (bl == "") viol(NR, "RL08", "Where must name the finding file, backlog/" f "-<slug>.md")
    else printf "B\t%d\t%s\n", NR, bl
  }
  if (s == "fixed" || s == "verified") {
    if (hash == "") viol(NR, "RL08", "Where must hold the 40-character hash of the fixing commit")
    else printf "C\t%d\t%s\n", NR, hash
  }
  if (s == "verified") {
    if (rev == "") viol(NR, "RL08", "Where must name the review that judged the finding resolved")
    else printf "X\t%d\t%s\t%s\n", NR, f, rev
  }
  if (s == "closed" && (w == "" || w == "-")) viol(NR, "RL08", "Where must say why the finding is closed")
}
function body_line(line) {
  if (part < 2) { viol(NR, "RL07", "content outside a section"); return }
  if (part == 2) { table_line(line); return }
  if (!in_fence && unfilled(line)) viol(NR, "RL08", "an unfilled placeholder")
  if (ri == 0) {
    if (nf == 0 && line == "None." && !reasons_none) reasons_none = 1
    else if (nf == 0) viol(NR, "RL08", "## Reasons holds None. alone when the record has no findings")
    else viol(NR, "RL08", "content before the first ### finding ID heading")
    return
  }
  r_n++
}
function dheading(line,    lvl, text) {
  match(line, /^#+/); lvl = RLENGTH
  text = trim(substr(line, lvl + 1))
  if (lvl == 1) {
    if (part != 0) viol(NR, "RL07", "a disposition file has one # heading, before its sections")
    else part = 1
    if (text != "R" nn " disposition") viol(NR, "RL07", "the # heading must be R" nn " disposition")
    return
  }
  if (lvl == 2) {
    if (text == "Dispositions" && part == 1) { part = 2; tn = 0; return }
    if (text == "Reasons" && part == 2) { end_table(); part = 3; return }
    viol(NR, "RL07", "unexpected, repeated, or misplaced section; the sections are Dispositions, Reasons")
    return
  }
  if (lvl == 3 && part == 3) {
    end_reason()
    ri++; r_line = NR; r_n = 0
    if (ri > nf) viol(NR, "RL08", "a reason for something that is not a finding of the record")
    else if (text != fid[ri]) viol(NR, "RL08", "expected the reason for " fid[ri] " here")
    return
  }
  viol(NR, "RL07", "unexpected heading")
}
BEGIN {
  nkeys = split("id|title|is_source_of_truth|derives_from|status|review|form", key, "|")
  want[1] = "review-r" nn "-disposition"; want[2] = "\"R" nn " disposition\""
  want[3] = "true"; want[4] = "[review-r" nn "]"; want[5] = "current"; want[6] = "R" nn
  want[7] = "1"
  header = "| Finding | Blocks MVP | Expensive later | Disposition | State | Where |"
  nf = split(findings, fid, " ")
  state = "start"; ki = 0; part = 0; rows = 0; ri = 0; tn = 0
}
NR == 1 {
  if ($0 != "---") { viol(1, "RL07", "line 1 must be ---"); state = "skip" }
  else state = "fm"
  next
}
state == "skip" { next }
state == "fm" {
  if ($0 == "---") {
    if (ki < nkeys) viol(NR, "RL07", "front matter ends before the key " key[ki + 1])
    state = "body"
    next
  }
  ki++
  if (ki > nkeys) viol(NR, "RL07", "unexpected front matter line")
  else if ($0 != key[ki] ": " want[ki]) viol(NR, "RL07", "expected the line " key[ki] ": " want[ki])
  next
}
state == "body" {
  line = $0
  # An indented fence line: outside a fence a renderer would open one there; inside a
  # fence it matters only when it could close the fence.
  indented = (line ~ /^[ \t]+(~~~|```+[^`]*$)/)
  if (indented && !in_fence) {
    viol(NR, "RL07", "a fence line starts in column 1"); next
  }
  if (in_fence) {
    bare = line; sub(/^[ \t]+/, "", bare)
    if (bare != line && fence_close(bare)) {
      viol(NR, "RL07", "a fence line starts in column 1"); next
    }
    body_line(line)
    if (fence_close(line)) in_fence = 0
    next
  }
  flen = fence_open(line)
  if (flen > 0) { in_fence = 1; body_line(line); next }
  if (line ~ /^[ \t]*</ && !unfilled(line)) {
    viol(NR, "RL07", "a line outside a fenced code block may not start with <: raw HTML is not allowed")
    next
  }
  if (contained(line)) {
    viol(NR, "RL07", "a heading, a fence, or a rule inside a quote or a list item is not allowed")
    next
  }
  if (line ~ /^[ \t]+#+([ \t]|$)/) { viol(NR, "RL07", "a heading starts in column 1"); next }
  if (line ~ /^[ \t]*(=+|-+)[ \t]*$/) {
    viol(NR, "RL07", "a line of = or - alone is not allowed; it would make the line above a heading")
    next
  }
  if (line ~ /^#+([ \t]|$)/) { dheading(line); next }
  if (line ~ /^[ \t]*$/) next
  body_line(line)
}
END {
  if (state == "start") viol(1, "RL07", "the file is empty")
  if (state == "fm") viol(NR, "RL07", "the front matter is not closed")
  if (state == "body") {
    if (in_fence) viol(NR, "RL07", "a fenced code block is not closed")
    if (part < 2) viol(NR, "RL07", "missing section: ## Dispositions")
    if (part == 2) { end_table(); viol(NR, "RL07", "missing section: ## Reasons") }
    if (part == 3) {
      end_reason()
      for (i = ri + 1; i <= nf; i++) viol(NR, "RL08", "no reason for the finding " fid[i])
      if (nf == 0 && !reasons_none) viol(NR, "RL08", "## Reasons must hold None. when the record has no findings")
    }
  }
  printf "E\t%d\n", NR
}
