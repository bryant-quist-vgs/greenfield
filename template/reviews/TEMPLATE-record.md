---
id: review-r<NN>
title: "R<NN>. <subject>"
is_source_of_truth: true
derives_from: [review-rubric]
status: current
review: R<NN>
form: 1
reviewed_commit: <reviewed-commit>
base_commit: <base-commit>
scope: <scope>
passes: <passes>
date: <YYYY-MM-DD>
reviewer: <reviewer>
---

# R<NN>. <subject>

## Scope

<What was read and judged at the reviewed commit, and what was not.>

## Prior findings

None.

## Findings

### R<NN>-F01 <title>

```finding
axis: <axis>
also: none
pass: <pass>
location: <path:line>
touches: <touches>
```

#### Observation

<What is there, stated so that a reader can find it.>

#### Evidence

<What shows it: the quoted text, the command and its output, the path the data takes.>

#### Consequence

<What goes wrong, for whom, and under what condition. No grade.>

#### Resolved when

<The condition that would close the finding. A condition, not a patch.>

## Remarks

None.

## Verification and limits

<Commands run with their results, and what could not be checked.>
