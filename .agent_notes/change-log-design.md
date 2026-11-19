---
name: change-log-design
description: The choices in the change log and its script that the owner did not state and has not confirmed, each with its reason; ask before building on one.
type: design
date: 2026-11-18
---

The owner asked for the change log and for its tags on 2026-11-18; the words are in
[owner-requirements](owner-requirements.md), items 10 and 11. The rules are in
`template/docs/greenfield/change-log.md`, and what the script does is in
`tools/change_log_contract.md`. Everything below is the maintaining agent's
choice, made that day. The owner has not confirmed any of it: ask before building on one,
and correct this note with the answer.

The entries and the log:

1. **An entry is named by UTC time and a slug, not numbered.** Reason: two branches that
   each add an entry would both take the next number, and the merge would not be
   trivial. Names made from the time and the title differ.
2. **An entry has "What changed" and "Why", and no list of files.** Reason: Git records
   the files.
3. **The log is newest first,** grouped by date.
4. **The template ships no entry.** `docs/change_log.md` is placed in the form the script
   generates for no entries, and `docs/change_log/` holds only `tags.md`.

What a session is, and the gate:

5. **A session is everything that differs from the base.** The base is the upstream
   commit, or `HEAD` when the clone knows no upstream. So a repository with no upstream
   needs a new or changed entry for every commit, and a branch with an upstream needs one
   entry for all the commits it adds: a second session on the same branch is not made to
   write its own.
6. **The script never fetches.** Reason: a fetch leaves the machine, so the operator runs
   it; the gate judges what the clone holds and can be behind the remote.
7. **The gate merges only into a clean working tree, and only a trivial merge.** The
   owner chose this on 2026-11-18 ([owner-requirements](owner-requirements.md), item
   12); the conditions in `change-log.md` §6 are the agent's reading of it. Clean means
   that `git status` lists nothing and no path is marked assume-unchanged or
   skip-worktree. Trivial means that the tested merge conflicts in nothing but the
   generated list, and that nothing stands at a path it adds. Any other merge is not
   started, and the gate says to commit the work and run `make commit` again.
8. **`make commit` writes.** Outside CI its `change-log` gate regenerates the list and
   may merge the upstream; under CI it only checks. The other gates of `make commit`
   leave the tracked files and the index as they were.
9. **The upstream is the branch `refs/remotes/origin/HEAD` names,** or the ref given as
   `make commit UPSTREAM=<ref>`. A repository whose remote was added by hand has no
   such ref until `git remote set-head origin <branch>` records one, and until then has
   no upstream.
10. **The order of a session is: entry, `make commit`, commit.** When the gate reports
    that the upstream is not merged: commit the work, `make commit` (the gate merges),
    `git commit --no-edit`, `make commit` again. A merge the gate makes is therefore in
    a commit of its own.
11. **No Git hook runs while the script works.** Reason: a hook is a program the
    contract cannot name.
12. **Why the gate does not merge over uncommitted work.** A merge run over such work
    can destroy what Git does not track, and a script that guards against it has to
    predict Git case by case: an ignored file where the merge writes; untracked work
    deleted by the stash and hard reset that `git merge` runs when the `ort` strategy
    fails on diverged branches, while `git status` reads the same before and after; an
    edited assume-unchanged file; a stray file in a submodule's directory; two names
    that differ only in case. Each was seen with Git 2.50.1 on 2026-11-18. Do not add a
    merge over uncommitted work unless the owner asks for it.
13. **An entry is a record: one that the base holds is not deleted or renamed.**

The tags:

14. **The twelve baseline tags and their meanings:** `breaking`, `design`, `docs`,
    `feature`, `fix`, `maintenance`, `performance`, `process`, `refactor`, `removal`,
    `security`, `test`. The owner named maintenance, a feature, a security fix, and a
    refactor, and "etc."; the other eight, and every meaning, are the agent's.
15. **The grammar:** a tag is `<word>` or `<namespace>:<word>`, each part 1 to 30
    characters, a lowercase letter and then lowercase letters, digits, and hyphens. A
    namespaced tag is always a project tag.
16. **An entry carries 1 to 4 tags,** in ascending byte order, none twice.
17. **At least one tag of an entry is a baseline tag.** Reason: the owner's aim is that
    projects tag the same kinds of change alike; an entry with project tags only would
    escape that.
18. **Project tags are declared in `docs/change_log/tags.md`,** which the project owns,
    beside the entries. A project cannot remove or redefine a baseline tag.
19. **The generated log has no index by tag.** A reader searches it for the tag in
    backticks.

The version:

20. **`VERSION` stays 0.1.0,** although the change log alters what `template/` places.
    Reason: nothing has been committed or released, so no repository carries 0.1.0.

Open, for the owner:

- The generated list fails the size gate at about 650 entries:
  `backlog/G006-generated-change-log-size.md`.

**Why:** the request named the documents, the generated log, one script, trivial merges,
`make commit`, and a baseline of tags that projects can extend. It did not say how. The
script was modelled on two Python tools of the owner's, `session_log.py` and the `sync`
command of `investigation.py`, under `~/sec_kb/triage_boilerplate/vgs_triage/`.

**How to apply:** a change to the entry form, the tags, or a rule moves `change-log.md`,
`template/tools/change_log*`, and its tests together (`AGENTS.md`). When
the owner confirms or changes one of these, say so here with the date.
