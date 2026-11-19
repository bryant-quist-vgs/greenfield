---
id: change-log-rules
title: Change log rules
is_source_of_truth: true
derives_from: [greenfield-specification]
status: policy
---

# Change log rules

The change log records what each session changed, and why. It is kept as the decisions
are ([specification.md §3.4](specification.md#34-decisions)): one file for each
[entry](../glossary.md#change-log-entry) under `docs/change_log/`, and
`docs/change_log.md` as the list of them. There is one difference: `docs/change_log.md` is
generated. `tools/change_log.sh` writes the whole file from the entries, and it MUST NOT
be edited by hand. This document is the home of the rules. The script's contract and its
tests are kept in the greenfield repository, at the version that `.greenfield-stamp`
records; no test of the script runs here. The key words MUST, SHOULD, and MAY are used
as in
[specification.md §1](specification.md#1-purpose-and-normative-language).

## 1. Entries

An entry is one file, `docs/change_log/<YYYY-MM-DD>-<hhmmss>-<slug>.md`, in exactly the
form below. The date and time are UTC. The slug is 1 to 6 words of lowercase letters and
digits, joined by hyphens.

```markdown
---
id: change-<YYYY-MM-DD>-<hhmmss>-<slug>
title: "<title>"
is_source_of_truth: true
derives_from: []
status: current
date: <YYYY-MM-DD>
tags: [<tag>, <tag>]
---

# <title>

## What changed

<one or more lines>

## Why

<one or more lines>
```

- `id` is `change-` and the file name without `.md`. `date` is the date in the file name,
  and is a real calendar date. The `#` heading is the title.
- The title is one line of 1 to 100 bytes, with no space at its start or its end. It
  holds no control character, no backtick, and none of `"` `\` `[` `]` `<` `>` `|`.
- `tags` holds 1 to 4 tags, by the rules of §2.
- The two `##` sections are present, in this order, each with content. An entry has no
  other heading, and every heading starts in column 1. A fenced code block is not read
  as one: no other line starts with `#` and a space, inside a fence either.
- No line starts with `<` or holds only `=` or only `-`, and no heading stands in a quote
  or a list item. A line that is one `<...>` and nothing else is read as a placeholder
  left unfilled.
- An entry holds no control character but the tab and the end of a line: no carriage
  return.
- An entry lists no files. Git records which files a change touched.

An entry is a record, and is where the history of a change is written
([.agent_notes/prose.md](../../.agent_notes/prose.md)).

## 2. Tags

A tag says what kind of change an entry records. A tag is `<word>` or
`<namespace>:<word>`. A word and a namespace are each 1 to 30 characters: a lowercase
letter, then lowercase letters, digits, and hyphens.

The **baseline tags** are the same in every repository, so that no project chooses its
own word for one of these kinds of change. A project MUST NOT remove or redefine one.

| Tag | An entry carries it when |
|---|---|
| `breaking` | someone who uses the project must change something to keep working; used with another tag |
| `design` | the design changed: the goal, the scope, the MVP, the threat model, a decision |
| `docs` | documents changed, other than the design |
| `feature` | the project does something it did not do before |
| `fix` | behavior that was wrong is corrected |
| `maintenance` | upkeep: dependencies, the toolchain, the build, CI, housekeeping |
| `performance` | the same behavior with less time or fewer resources |
| `process` | how work is done here changed: gates, the review procedure, the backlog, instructions for agents |
| `refactor` | structure changed and behavior did not |
| `removal` | something the project did is taken away, or marked to be |
| `security` | the change is made for a security reason: a vulnerability closed, a control added or tightened |
| `test` | tests added or changed, with no change in behavior |

A **project tag** is a tag the project adds. It is declared in `docs/change_log/tags.md`,
which the project owns and edits by hand: one row of the table there for each tag, with
the tag in backticks in the first cell and its meaning in the second. A bare word that is
not a baseline tag, and every namespaced tag, is a project tag. `tags.md` is the one file
under `docs/change_log/` that is not an entry.

In an entry the tags are separated by a comma and a space, in ascending byte order (the
order of `LC_ALL=C sort`), and none appears twice. Each is a baseline tag or a tag
declared in `docs/change_log/tags.md`, and at least one is a baseline tag.

## 3. The generated list

`docs/change_log.md` lists every entry whose name, title, and tags can be read (CL02
reports one that is left out), newest first: a `## YYYY-MM-DD` heading for each date, and
under it one line for each entry of that date. The line is a link whose text is the
entry's title and whose target is the entry's file, then the entry's tags in parentheses,
each in backticks. With no entry the file holds the line `No entries yet.` The same
entries always give the same bytes. The file has no index by tag: to find the entries
that carry a tag, search it for the tag in backticks.

`make change-log-entry` regenerates the file, and so does the `change-log` gate outside
CI. A conflict that Git reports in it is not resolved by hand: the gate generates the
file again from the entries (§6).

## 4. Recording a session

A session's changes are every path that differs between the **base** and the index or
the working tree: staged and unstaged changes, and untracked files that Git does not
ignore. `docs/change_log.md` and the paths under `docs/change_log/` are not counted. The
base is the [upstream](../glossary.md#upstream) commit when an upstream is known (§6), and
`HEAD` when none is.

When a session has changes, at least one entry MUST exist that the base does not hold, or
holds differently (rule CL04). `tags.md` is not an entry and does not meet the rule. Where
an upstream is known, the comparison takes in every commit the branch adds to it, so one
entry that is new or changed against the upstream meets the rule for all of them. Where
none is known the base is `HEAD`, so every commit needs a new or changed entry.

An entry is a record. An entry that the base holds MUST NOT be deleted or renamed, and
CL04 reports one that is missing.

The first commit of a new repository needs no entry: the rule is not applied in a
repository that has no commit. In a repository that had commits before greenfield was
placed in it, the placed files are a change like any other and need an entry.

The [working agent](../glossary.md#working-agent) records a session in this order:

1. Run `make change-log-entry TITLE="<title>" TAGS="<tag> <tag>"`. `TAGS` is required and
   holds the tags separated by spaces or commas; they are checked by the rules of §2
   before anything is written. This creates the entry, named from the UTC clock and the
   first six words of the title, with its tags sorted. It regenerates
   `docs/change_log.md` and prints the entry's path. It never overwrites an entry. The
   title and the tags reach the script as typed: `make` expands nothing in them.
2. In the entry, replace the placeholder line under `## What changed` and the one under
   `## Why`.
3. Run `make commit`.
4. When it passes, stage the entry and `docs/change_log.md` with the rest of the change,
   and commit. An entry left untracked is missing from the commit, and the gate fails
   in CI.

If step 3 reports under CL05 that the upstream is not merged, the gate has made no
merge, because it merges only into a working tree with no uncommitted change (§6).
Commit the work as in step 4, then run `make commit` again: the gate merges the
upstream when the merge is trivial, and the other gates then judge the merged tree.
When it passes, complete the merge with `git commit --no-edit`. If a gate failed on the
merged tree and files were changed to make it pass, stage them first: that commit holds
only what is staged.

## 5. The `change-log` gate

`make commit` runs `make change-log` before every other gate, so that the other gates
judge the merged tree. Outside CI the gate writes. In order, it merges the upstream when
that is not merged and the merge is trivial (§6), regenerates `docs/change_log.md`, and
checks the rules below. Under CI it checks the rules and changes nothing: that is when
the `CI` variable is set to any value, `0` and `false` included, as in
`make commit CI=1`. The placed CI workflow records the default branch of `origin` in its
clone before the gate runs, so that the gate there knows its upstream.

| Rule | Requires |
|---|---|
| CL01 | Everything Git lists under `docs/change_log/`, tracked or untracked and not ignored, is a regular file, not a link, directly in the directory, and is `tags.md` or has a name of the form in §1. |
| CL02 | Every entry has the form in §1, with tags by the rules of §2. |
| CL03 | `docs/change_log.md` is exactly what the entries generate. |
| CL04 | The session is recorded, and no entry the base holds is missing (§4). Not applied in a repository with no commit, nor while CL05 fails. |
| CL05 | No path is unmerged. When an upstream is known, it is merged: its commit is an ancestor of `HEAD`, or a merge that holds it is in progress. |
| CL06 | `docs/change_log/tags.md` exists and is a regular file. It holds its table header and separator row exactly once. Every row has two cells: one tag in backticks that fits the grammar, and a meaning that is not empty. No tag is declared twice, and no row declares a baseline tag. |

A fault in `tags.md` is reported under CL06 and does not stop the other rules from being
checked: CL02 then accepts the baseline tags and the project tags that are validly
declared.

The script prints each violation on one line, `<path>:<line>: CL<nn> <message>`, with
Git's own text indented beneath it where that is the cause, then lines that begin
`change-log:`, the last of which is the summary. It exits 0 with no violation, 1 with one
or more, and 2 when it could not make the check: a gate that cannot check does not pass.

## 6. Upstream and merging

The upstream is the branch that `refs/remotes/origin/HEAD` names in this clone. A branch
built on another branch names that branch as its upstream: `make commit UPSTREAM=<ref>`.
When no upstream is known, the gate says so in its summary line, CL05 judges unmerged
paths only, and the base of §4 is `HEAD`. Where a remote `origin` has no default branch
recorded, run `git remote set-head origin <branch>`, which stays on the machine. In a
partial clone the gate exits 2, and so it does in a shallow clone that has an upstream.

The script never contacts a remote. It does not fetch, pull, or push, and it judges what
the clone holds. The [operator](../glossary.md#operator) runs `git fetch` (an agent hands
it over) to bring the clone's copy of the upstream up to date.

The gate makes a merge only when the upstream's commit is not an ancestor of `HEAD`,
`HEAD` is a branch with a commit, no merge is in progress, and no path is unmerged. On a
detached `HEAD` it makes none, reports under CL05, and says to switch to a branch and
run `make commit` again. It tests the merge first, without touching the index or the
working tree; the test needs Git 2.38 or later. A merge is **trivial** when all of these
hold:

- the working tree is clean: nothing is staged, no tracked path is changed, and no file
  stands there that Git neither tracks nor ignores. Uncommitted work inside a submodule
  is not looked at, and the merge leaves a submodule's own files as they are;
- no path is marked assume-unchanged or skip-worktree, because Git does not look at such
  a file. A sparse checkout marks paths skip-worktree, and so gets no merge from the
  gate;
- the merge has no conflict, or its only conflicted path is `docs/change_log.md`;
- nothing stands at a path that the merge adds, and nothing that is no directory stands
  where the merge needs a directory. In a clean working tree, what stands there is a
  file that Git ignores, or the same name in another case on a file system that does
  not tell the two apart; Git writes over either without a word. What the merge itself
  removes does not count, nor does an empty directory. The directory of a submodule
  that the merge replaces by a file is empty.

- **A trivial merge** is made by the gate, with `git merge --no-commit`. The gate prints
  the upstream ref and its full hash. The merge is in the index and is not committed:
  `git commit --no-edit` completes it, and that commit holds the merge alone. A branch
  with no commit of its own is moved forward to the upstream, and nothing is left to
  complete.
- **Any other merge** is not started: the gate runs no `git merge`, and leaves the index,
  the working tree, and `HEAD` as they were, apart from regenerating
  `docs/change_log.md`. It reports under CL05 why, with the paths or with Git's own text,
  and what to do:
  - the working tree is not clean: commit the work in progress, then run `make commit`
    again. The gate then tests the merge, and makes it when the merge is trivial;
  - a path is marked: clear the mark with `git update-index`, then run `make commit`
    again. In a sparse checkout leave the marks, which are what makes it sparse, and
    merge by hand;
  - something stands where the merge writes: move it away, then run `make commit` again.
    One case differs: when it is a tracked file whose name the upstream changed only in
    the case of letters, on a file system that does not tell the two apart, do not move
    it; run `git merge <hash>` in the clean working tree;
  - the merge conflicts in another path, or this Git cannot test it: run the
    `git merge <hash>` command the gate prints, resolve every conflicted path other
    than `docs/change_log.md`, and run `make commit` again. The gate prints that command
    only for a clean working tree with no marked path. Where it tested the merge, it
    prints it only when nothing stands where the merge writes; where it could not test,
    it says to look at `git status --ignored` first, because a merge by hand writes
    over an ignored file without a word. On a branch with no commit it says to move
    the uncommitted work away first.

Git can still refuse a merge the gate started, for a reason the gate cannot foresee,
such as a locked index. The gate then reports Git's text under CL05 and says what it
compared: `HEAD`, `MERGE_HEAD`, the index, and the answer of `git status` are as they
were. If Git stops part-way through a merge, because it could not write a path, the
gate exits 2 and names what it found changed: it does not undo it.

While a merge is in progress the gate starts no merge. Outside CI it regenerates
`docs/change_log.md` and stages that file, so that the merge can be completed, or
abandoned with `git merge --abort`. It reports every other unmerged path under CL05.
This is how a conflict in the generated list is resolved, in a merge the gate made or in
one made by hand: the list is generated again from the entries of both sides.

The script stages no other path. It runs no commit, abort of a merge, stash, reset,
rebase, or checkout, and no Git hook runs while it works. Git itself stashes and resets
inside a merge of diverged branches that it refuses, which is one reason the gate merges
only into a clean working tree.

Three limits. CL05 judges ancestry: a merge made by hand that discards what the upstream
changed still passes. The upstream is what this clone records: the gate in CI, on a fresh
clone, is the one that judges against the remote. And the placed CI judges every branch
against the default branch: a branch built on another branch passes there once the
default branch is merged into it.
