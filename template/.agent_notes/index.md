---
id: agent-notes
title: Agent notes
is_source_of_truth: false
derives_from: []
status: current
---

# Agent notes

The memory store for agents working in this repository. It is tracked in Git and belongs to
no vendor: every agent reads it and every agent may add to it. `AGENTS.md` sends each
session here first.

Notes are an aid, not an authority. Where a note and a document under `docs/` disagree,
the document is right and the note is corrected or deleted.

## Rules

- **One note, one file, one fact.** `.agent_notes/<short-kebab-case-name>.md`.
- **Every note has a line in the index below.** A note with no line is not found; a line
  with no note is removed.
- **Write a note when** you learned something a later session would have to rediscover and
  no document is its home: a preference the owner stated, a fact about the environment or
  the sandbox, a trap in a tool, a pointer to something outside the repository.
- **Do not write a note for** a decision (it goes to `docs/decisions/`), what a change did
  and why (`docs/change_log/`), work to be done (`backlog/`), an unknown
  (`docs/open-questions.md`), anything the code or Git history already records, or the
  state of a task in progress.
- **Never write a secret** in a note, or personal data that the work does not need.
- **Check before you write.** Update the note that already covers the subject. Delete a
  note that has stopped being true.
- **Date what can go stale.** Use absolute dates. Say how the fact was learned, so that a
  later reader can check it.

## Form of a note

```markdown
---
name: <the file name without .md>
description: <one line; this is what a reader uses to decide whether to open the note>
type: owner | environment | tooling | reference
date: YYYY-MM-DD
---

The fact. Then, where it helps:

**Why:** how it was learned, or the reason behind it.
**How to apply:** what to do differently because of it.
```

## Index

One line for each note: a link whose text is the note's name and whose target is its file,
then a colon and what the note says.

- [prose](prose.md): the owner's six rules for every page; read before writing or editing
  prose.
