# review_lint_record.awk — the record parser of review_lint.sh.
# Built against contract v2, which is kept with the tests in the greenfield repository,
# under tools/.
# review_lint.sh runs it on one record, with the number from that record's file name:
#   awk -v nn=<NN> -f review_lint_record.awk <absolute path of reviews/R<NN>-<slug>.md>
# Prints tab-separated lines and nothing else:
#   V <line> <rule> <message>        a violation
#   F <line> <finding id>            a finding entry
#   C <line> <hash>                  a commit to look up
#   P <line> <finding id> <result>   a prior-findings row
#   E <lines read>                   the last line: the file was read to its end
# Messages are fixed text: nothing read from the record is printed except a finding ID
# or a hash that has already been checked against its pattern, and a result that is one
# of the allowed values.
function viol(line, rule, msg) { printf "V\t%d\t%s\t%s\n", line, rule, msg }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function ishash(s) { return length(s) == 40 && s !~ /[^0-9a-f]/ }
function unfilled(s) { return s ~ /^<[^<>]+>$/ }
function inlist(list, x) {
  return x != "" && index(x, " ") == 0 && index(" " list " ", " " x " ") > 0
}
# A fence opens in column 1 with three or more backticks or tildes; a backtick fence has
# no backtick after its opening run. It closes on a line of at least as many of the same
# character, with nothing after them but spaces or tabs.
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
# A quote or a list item that holds a heading, a fence, or a rule: a renderer would show
# structure there that this program reads as plain content.
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
# A table row with each cell trimmed, "| a | b |"; a separator row of <want> cells.
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
function check_date(val,    m, d) {
  if (val !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  m = substr(val, 6, 2) + 0; d = substr(val, 9, 2) + 0
  return m >= 1 && m <= 12 && d >= 1 && d <= 31
}
function check_key(k, val) {
  if (unfilled(val)) { viol(NR, "RL02", "an unfilled placeholder"); return }
  if (k == "id") {
    if (val != "review-r" nn) viol(NR, "RL02", "id must be review-r" nn)
  } else if (k == "title") {
    if (val !~ /^"R[0-9][0-9]\. .+"$/ || substr(val, 2, 3) != "R" nn)
      viol(NR, "RL02", "title must be \"R" nn ". <subject>\" in double quotes")
    else {
      title = substr(val, 2, length(val) - 2)
      if (unfilled(substr(title, 6))) viol(NR, "RL02", "an unfilled placeholder")
    }
  } else if (k == "is_source_of_truth") {
    if (val != "true") viol(NR, "RL02", "is_source_of_truth must be true")
  } else if (k == "derives_from") {
    if (val != "[review-rubric]") viol(NR, "RL02", "derives_from must be [review-rubric]")
  } else if (k == "status") {
    if (val != "current") viol(NR, "RL02", "status must be current")
  } else if (k == "review") {
    if (val != "R" nn) viol(NR, "RL02", "review must be R" nn)
  } else if (k == "form") {
    if (val != "1") viol(NR, "RL02", "form must be 1")
  } else if (k == "reviewed_commit") {
    if (!ishash(val)) viol(NR, "RL02", "reviewed_commit must be 40 lowercase hexadecimal characters")
    else printf "C\t%d\t%s\n", NR, val
  } else if (k == "base_commit") {
    base = val
    if (val != "none") {
      if (!ishash(val)) viol(NR, "RL02", "base_commit must be 40 lowercase hexadecimal characters, or none")
      else printf "C\t%d\t%s\n", NR, val
    }
  } else if (k == "scope") {
    scope = val
    if (!inlist("design-increment whole-design change fix milestone", val))
      viol(NR, "RL02", "scope must be design-increment, whole-design, change, fix, or milestone")
  } else if (k == "passes") {
    passes = val
    if (val != "per-item" && val != "cross-item" && val != "per-item, cross-item")
      viol(NR, "RL02", "passes must be per-item, cross-item, or per-item, cross-item")
  } else if (k == "date") {
    if (!check_date(val)) viol(NR, "RL02", "date must be a date, YYYY-MM-DD")
  } else if (k == "reviewer") {
    if (trim(val) == "") viol(NR, "RL02", "reviewer must not be empty")
  }
}
function check_field(k, val,    n, a, i, t, seen, haslocal) {
  if (unfilled(val)) { viol(NR, "RL05", "an unfilled placeholder"); return }
  if (k == "axis") {
    axis = val
    if (!inlist(peraxes " " crossaxes " other", val)) viol(NR, "RL05", "axis is not a rubric value")
  } else if (k == "also") {
    if (trim(val) == "") viol(NR, "RL05", "also must be none or axis values")
    else if (val != "none") {
      n = split(val, a, ","); seen = " "
      for (i = 1; i <= n; i++) {
        t = trim(a[i])
        if (!inlist(peraxes " " crossaxes " other", t))
          viol(NR, "RL05", "also holds a value that is not an axis; write none or axis values")
        else if (t == axis) viol(NR, "RL05", "also repeats the axis")
        else if (index(seen, " " t " ") > 0) viol(NR, "RL05", "also repeats a value")
        seen = seen t " "
      }
    }
  } else if (k == "pass") {
    if (val != "per-item" && val != "cross-item") viol(NR, "RL05", "pass must be per-item or cross-item")
    else {
      if (passes != "" && index(passes, val) == 0)
        viol(NR, "RL05", "pass is not among the passes the front matter names")
      if (inlist(peraxes, axis) && val != "per-item")
        viol(NR, "RL05", "this axis belongs to the per-item pass")
      if (inlist(crossaxes, axis) && val != "cross-item")
        viol(NR, "RL05", "this axis belongs to the cross-item pass")
    }
  } else if (k == "location") {
    if (trim(val) == "") viol(NR, "RL05", "location must not be empty")
  } else if (k == "touches") {
    n = split(val, a, ","); seen = " "; haslocal = 0
    if (trim(val) == "") viol(NR, "RL05", "touches must not be empty")
    else for (i = 1; i <= n; i++) {
      t = trim(a[i])
      if (!inlist(touchv, t)) viol(NR, "RL05", "touches holds a value that is not in the rubric")
      else if (index(seen, " " t " ") > 0) viol(NR, "RL05", "touches repeats a value")
      seen = seen t " "
      if (t == "local") haslocal = 1
    }
    if (haslocal && n > 1) viol(NR, "RL05", "touches: local stands alone")
  }
}
function end_sub() {
  if (fcount > 0 && sub_i > 0 && sub_i <= 4 && sub_n == 0)
    viol(sub_line, "RL05", "#### " subname[sub_i] " is empty")
}
function end_finding() {
  if (fcount == 0) return
  if (fstate == "want-block") viol(f_line, "RL05", "the finding has no field block")
  else if (fstate == "block") viol(f_line, "RL05", "the field block is not closed")
  end_sub()
  if (sub_i < 4) viol(f_line, "RL05", "the finding lacks #### " subname[sub_i + 1])
  fstate = ""
}
function end_section() {
  if (cur == 1 && sec_n == 0) viol(sec_line, "RL04", "## Scope is empty")
  if (cur == 2) {
    if (sec_n == 0) viol(sec_line, "RL06", "## Prior findings is empty; write None. or a table")
    else if (!prior_none && prior_rows == 0) viol(sec_line, "RL06", "the prior findings table has no rows")
    if ((sec_n == 0 || prior_none) && scope == "fix")
      viol(sec_line, "RL06", "a review with the scope fix needs a prior findings table")
  }
  if (cur == 3) {
    end_finding()
    if (fcount == 0 && !find_none) viol(sec_line, "RL05", "## Findings is empty; write None. or finding entries")
    if (fcount > 0 && find_none) viol(sec_line, "RL05", "## Findings holds both None. and entries")
  }
  if (cur == 4 && sec_n == 0) viol(sec_line, "RL04", "## Remarks is empty; write None. or remarks")
  if (cur == 5 && sec_n == 0) viol(sec_line, "RL04", "## Verification and limits is empty")
}
function prior_line(line,    n, c, id, res, ev, i) {
  if (sec_n == 1) {
    if (line == "None.") { prior_none = 1; return }
    if (norm(line) != "| Finding | Result | Evidence |")
      viol(NR, "RL06", "expected None. or the table header | Finding | Result | Evidence |")
    return
  }
  if (prior_none) { viol(NR, "RL06", "## Prior findings holds None. alone, or a table"); return }
  if (sec_n == 2) {
    if (!is_sep(line, 3)) viol(NR, "RL06", "expected the separator row |---|---|---|")
    return
  }
  prior_rows++
  if (line !~ /^\|.*\|$/) { viol(NR, "RL06", "not a table row"); return }
  n = split(line, c, "|")
  id = trim(c[2]); res = trim(c[3]); ev = ""
  for (i = 4; i < n; i++) ev = ev (i > 4 ? "|" : "") c[i]
  if (id !~ /^R[0-9][0-9]-F[0-9][0-9]$/) { viol(NR, "RL06", "the first cell must be a finding ID"); return }
  if (index(prior_seen, " " id " ") > 0) { viol(NR, "RL06", "a second row for the finding " id); return }
  prior_seen = prior_seen id " "
  if (!inlist("resolved partly-resolved not-resolved", res)) {
    viol(NR, "RL06", "Result must be resolved, partly-resolved, or not-resolved"); return
  }
  if (trim(ev) == "" || unfilled(trim(ev))) viol(NR, "RL06", "Evidence is empty")
  printf "P\t%d\t%s\t%s\n", NR, id, res
}
function content(line) {
  if (cur == 0) { viol(NR, "RL04", "content outside a section"); return }
  if (!in_fence && unfilled(line)) viol(NR, "RL04", "an unfilled placeholder")
  sec_n++
  if (cur == 2) prior_line(line)
  else if (cur == 3) {
    if (fcount == 0) {
      if (line == "None." && sec_n == 1) find_none = 1
      else viol(NR, "RL05", "## Findings holds None. alone, or finding entries")
    } else if (sub_i == 0) viol(NR, "RL05", "content before #### Observation")
    else sub_n++
  }
}
function heading(line,    lvl, text, j, m, hit, id, sp, ftitle, want) {
  match(line, /^#+/); lvl = RLENGTH
  text = trim(substr(line, lvl + 1))
  if (lvl == 1) {
    if (h1) viol(NR, "RL04", "a record has one # heading")
    else {
      h1 = 1
      if (sec > 0 || cur > 0) viol(NR, "RL04", "the # heading comes before the sections")
      if (title != "" && text != title) viol(NR, "RL04", "the # heading must be the title without its quotes")
    }
    return
  }
  if (lvl == 2) {
    end_section()
    hit = 0
    for (j = sec + 1; j <= 5; j++) if (secname[j] == text) { hit = j; break }
    if (hit == 0) {
      viol(NR, "RL04", "unexpected, repeated, or misplaced section; the sections are Scope, Prior findings, Findings, Remarks, Verification and limits")
      cur = 0; sink = 1
      return
    }
    for (m = sec + 1; m < hit; m++) viol(NR, "RL04", "missing section before this one: ## " secname[m])
    sec = hit; cur = hit; sink = 0; sec_n = 0; sec_line = NR
    return
  }
  if (lvl == 3) {
    if (cur != 3) { viol(NR, "RL04", "a ### heading is allowed only under ## Findings"); return }
    end_finding()
    fcount++; f_line = NR; fstate = "want-block"; sub_i = 0; sub_n = 0
    want = "R" nn "-F" sprintf("%02d", fcount)
    id = text; ftitle = ""
    sp = index(text, " ")
    if (sp > 0) { id = substr(text, 1, sp - 1); ftitle = trim(substr(text, sp + 1)) }
    if (id != want) viol(NR, "RL05", "expected the finding ID " want " here")
    if (ftitle == "") viol(NR, "RL05", "a finding needs a title after its ID")
    else if (unfilled(ftitle)) viol(NR, "RL05", "an unfilled placeholder")
    printf "F\t%d\t%s\n", NR, want
    return
  }
  if (lvl == 4) {
    if (cur != 3 || fcount == 0 || fstate != "body") {
      viol(NR, "RL04", "a #### heading is allowed only inside a finding, after its field block"); return
    }
    end_sub()
    sub_i++; sub_n = 0; sub_line = NR
    if (sub_i > 4) viol(NR, "RL05", "a finding has four #### sections; this one is extra")
    else if (text != subname[sub_i]) viol(NR, "RL05", "expected #### " subname[sub_i] " here")
    return
  }
  viol(NR, "RL04", "a record has no heading below ####")
}
BEGIN {
  nkeys = split("id title is_source_of_truth derives_from status review form reviewed_commit base_commit scope passes date reviewer", key, " ")
  split("Scope|Prior findings|Findings|Remarks|Verification and limits", secname, "|")
  split("Observation|Evidence|Consequence|Resolved when", subname, "|")
  split("axis also pass location touches", fkey, " ")
  peraxes = "completeness correctness security verification-integrity scope maintainability documentation reliability"
  crossaxes = "consistency composed-security distributed-malice style-coherence coverage-adequacy contract-coherence"
  touchv = "interface data-format persisted-data trust-boundary component-boundary test-harness core-dependency local"
  state = "start"; ki = 0; sec = 0; cur = 0; fcount = 0; h1 = 0; prior_seen = " "
}
NR == 1 {
  if ($0 != "---") { viol(1, "RL02", "line 1 must be ---"); state = "skip" }
  else state = "fm"
  next
}
state == "skip" { next }
state == "fm" {
  if ($0 == "---") {
    if (ki < nkeys) viol(NR, "RL02", "front matter ends before the key " key[ki + 1])
    if (scope == "fix" && base == "none") viol(NR, "RL02", "base_commit must be a hash when scope is fix")
    state = "body"
    next
  }
  p = index($0, ": ")
  k = (p > 0) ? substr($0, 1, p - 1) : $0
  val = (p > 0) ? substr($0, p + 2) : ""
  hit = 0
  for (j = ki + 1; j <= nkeys; j++) if (key[j] == k) { hit = j; break }
  if (hit == 0) { viol(NR, "RL02", "unexpected, repeated, or misplaced front matter line"); next }
  for (m = ki + 1; m < hit; m++) viol(NR, "RL02", "missing front matter key before this one: " key[m])
  ki = hit
  check_key(k, val)
  next
}
state == "body" {
  line = $0
  # An indented fence line: outside a fence a renderer would open one there; inside a
  # fence it matters only when it could close the fence. Inside a finding's field block
  # it is left to the checks of that block, which report every line that is not the
  # expected key.
  indented = (line ~ /^[ \t]+(~~~|```+[^`]*$)/)
  if (indented && !in_fence && !(cur == 3 && fstate == "block")) {
    viol(NR, "RL04", "a fence line starts in column 1"); next
  }
  if (cur == 3 && fstate == "want-block") {
    if (line ~ /^[ \t]*$/) next
    if (line == "```finding") { fstate = "block"; bi = 0; next }
    viol(NR, "RL05", "the field block (```finding) must be the first content of a finding")
    fstate = "body"; sub_i = 0
  }
  if (cur == 3 && fstate == "block") {
    if (line == "```") {
      if (bi < 5) viol(NR, "RL05", "the field block ends before the key " fkey[bi + 1])
      fstate = "body"; sub_i = 0
      next
    }
    bi++
    if (bi > 5) { viol(NR, "RL05", "unexpected line in the field block"); next }
    p = index(line, ": ")
    k = (p > 0) ? substr(line, 1, p - 1) : line
    val = (p > 0) ? substr(line, p + 2) : ""
    if (k != fkey[bi]) { viol(NR, "RL05", "expected the key " fkey[bi] " here"); next }
    check_field(k, val)
    next
  }
  if (in_fence) {
    bare = line; sub(/^[ \t]+/, "", bare)
    if (bare != line && fence_close(bare)) {
      viol(NR, "RL04", "a fence line starts in column 1"); next
    }
    if (!sink) content(line)
    if (fence_close(line)) in_fence = 0
    next
  }
  flen = fence_open(line)
  if (flen > 0) { in_fence = 1; if (!sink) content(line); next }
  if (line ~ /^[ \t]*</ && !unfilled(line)) {
    viol(NR, "RL04", "a line outside a fenced code block may not start with <: raw HTML is not allowed")
    next
  }
  if (contained(line)) {
    viol(NR, "RL04", "a heading, a fence, or a rule inside a quote or a list item is not allowed")
    next
  }
  if (line ~ /^[ \t]+#+([ \t]|$)/) { viol(NR, "RL04", "a heading starts in column 1"); next }
  if (line ~ /^[ \t]*(=+|-+)[ \t]*$/) {
    viol(NR, "RL04", "a line of = or - alone is not allowed; it would make the line above a heading")
    next
  }
  if (line ~ /^#+([ \t]|$)/) { heading(line); next }
  if (line ~ /^[ \t]*$/) next
  if (!sink) content(line)
}
END {
  if (state == "start") viol(1, "RL02", "the file is empty")
  if (state == "fm") viol(NR, "RL02", "the front matter is not closed")
  if (state == "body") {
    if (in_fence) viol(NR, "RL04", "a fenced code block is not closed")
    end_section()
    for (m = sec + 1; m <= 5; m++) viol(NR, "RL04", "missing section: ## " secname[m])
    if (!h1) viol(NR, "RL04", "missing the # heading")
  }
  printf "E\t%d\n", NR
}
