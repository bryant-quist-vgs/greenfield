---
id: reviews
title: Reviews
is_source_of_truth: false
derives_from: [adversarial-review]
status: current
---

# Reviews

The record of every [adversarial review](../docs/glossary.md#adversarial-review) of
@@PROJECT_NAME@@. The rules are in
[docs/greenfield/adversarial-review.md](../docs/greenfield/adversarial-review.md), which is
their home; this page only says what the files are.

| File | Written by | Changes after it is committed |
|---|---|---|
| `R<NN>-<slug>.md` | The reviewer. Committed as returned. | Never. |
| `R<NN>-disposition.md` | The working agent; the owner confirms. | Yes: a finding's state and where it is tracked. |
| `TEMPLATE-record.md` | Greenfield. The blank form of a record. | Not edited here. |
| `TEMPLATE-disposition.md` | Greenfield. The blank form of a disposition file. | Not edited here. |

In the blank forms, every `<...>` is replaced. Where a record has no findings, the
Findings section holds `None.`, the disposition table has no rows, and the Reasons section
holds `None.`

Run `make reviews-lint` before the first commit of a record: it checks every file here, and
a record cannot be corrected afterwards.

Reviews are numbered from R01 in the order they are requested. The next number is one more
than the highest here.

Run these from the repository root. The first lists the records and disposition files, the
second prints each reviewed commit, and the last lists every finding that is still open or
awaits verification.

```
ls reviews/R[0-9]*.md
grep -h '^reviewed_commit: ' reviews/R[0-9]*.md
grep -h '^| R[0-9]*-F[0-9]* |' reviews/R*-disposition.md | grep -v '| verified |\|| closed |'
```
