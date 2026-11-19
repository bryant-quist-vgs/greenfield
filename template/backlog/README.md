---
id: backlog
title: Backlog
is_source_of_truth: true
derives_from: [greenfield-specification]
status: current
---

# Backlog

One file for each piece of work that belongs to the current delivery of @@PROJECT_NAME@@
and is not done. The files in this directory are the list: there is no separate index to
keep in step. Work the project intends to do after the current delivery is in
[docs/deferred-work.md](../docs/deferred-work.md). Things it will not do are in
[docs/out-of-scope.md](../docs/out-of-scope.md).

## Rules

- A [backlog item](../docs/glossary.md#backlog-item) names **one bounded deliverable**. An
  item that spans unrelated deliverables is split.
- An item is sized so that one session can finish and verify it without memory of another
  session. Everything a session needs is in the item or linked from it. Where the item
  depends on a binding value (a default, an exact name, an edge case), it quotes the value
  and cites its home.
- An item's file is **deleted in the change that completes it**. The commit message names
  the item. What was done is in the change log and in Git history; what remains is in this
  directory.
- A work item is `B<NNN>-<slug>.md`. The next number is on the line below; raise it in the
  change that takes it. Numbers are never reused.
- A review [finding](../docs/glossary.md#finding) left for later is
  `R<NN>-F<MM>-<slug>.md`, named by its finding ID. Every such file is brought to an end
  before the [MVP](../docs/glossary.md#mvp) is declared
  ([adversarial-review.md §9](../docs/greenfield/adversarial-review.md#9-findings-left-for-later)).

Next work item number: B007

## Order

An item can be started when its `Depends on` names nothing that still has a file here. Run
these from the repository root to list the items and what each depends on:

```
ls backlog/
grep -H '^- \*\*Depends on:\*\*' backlog/[BR][0-9]*.md
```

## Form of a work item

```markdown
---
id: backlog-b<NNN>
title: "B<NNN> <title>"
is_source_of_truth: true
derives_from: [<the documents this item implements>]
status: current
---

# B<NNN> <title>

- **State:** open | in progress (who, since when) | blocked (on what).
- **Blocks MVP:** yes | no.
- **Depends on:** item IDs, open questions, or nothing.
- **Owner:** who decides questions about this item.

## Deliverable

The one thing that exists when this is done.

## Implements or updates

The documents this work carries out, and the documents it must change.

## Consumer

What calls or uses the deliverable, or the exact item that will wire it.

## Tests required

The tests that must exist, including the negative control for each.

## Done when

Conditions a reader can check, and the evidence expected for each.
```

## Form of a finding left for later

```markdown
---
id: backlog-r<NN>-f<MM>
title: "R<NN>-F<MM> <the finding's title>"
is_source_of_truth: true
derives_from: [review-r<NN>]
status: current
---

# R<NN>-F<MM> <the finding's title>

- **State:** open.
- **Source:** review R<NN>, against commit `<40-character hash>`. The finding itself is
  in `reviews/R<NN>-<slug>.md` and is not restated here.
- **Filed:** YYYY-MM-DD. **Owner:** who decides.
- **Why it can wait:** why it does not block the MVP and is cheap to fix later.

## What a fix must do

Numbered conditions. A condition, not a patch.

## Where the fix goes

The files and sections a fix would change.

## Until it is fixed

What must not be relied on, and what to do instead.

## Done when

The conditions that end it: fixed and verified by a review, or closed with the reason. This
file is deleted in the change that ends it, and the finding's row in
`reviews/R<NN>-disposition.md` is updated in the same change.
```
