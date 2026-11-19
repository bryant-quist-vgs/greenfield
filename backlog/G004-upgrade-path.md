# G004 A way for a placed repository to take a newer greenfield

- **State:** open.
- **Depends on:** experience with at least one repository started from greenfield.
- **Owner:** Bryant Quist.

## Deliverable

A documented procedure, and a script if the procedure proves mechanical, by which a
repository stamped with version X compares its greenfield-owned files with version Y and
takes the new ones: `docs/greenfield/`, `tools/review_lint*`, `tools/change_log*`,
`reviews/TEMPLATE-*.md`, and the stamp.

## Why

The specification tells projects not to edit greenfield-owned files, so that the placed
copy can be compared with another version of greenfield. Nothing does the comparing. A
change to the review form is the hard case: a record already committed keeps the form it
was written to and must not be changed, so the linter has to know which form a record is
written to, or the committed records have to be accepted as they are.

## Open points

- A record and a disposition file carry `form: 1`, and the linter accepts only that
  value. When the form changes, the linter must keep reading form 1 records as form 1:
  how it carries two forms at once is not designed.
- Is `.greenfield-stamp` rewritten on upgrade, or does it keep a history?
- A repository placed without the change log lacks more than greenfield-owned files. It
  has no `docs/change_log.md` and no `docs/change_log/tags.md`, and its `Makefile`, which
  the project owns and has edited, has no `change-log` target, no `change-log-entry`
  target, and no `change-log` prerequisite of `commit`. The procedure says how it takes
  each, and whether the commits it already has get entries.
- The baseline change log tags are fixed by greenfield and a project declares its own
  beside them. If a version adds a baseline tag that a project has declared as its own,
  that project's `tags.md` fails rule CL06 on upgrade: how the baseline set may grow is
  not designed.

## Done when

One real repository has been moved from one version to the next by the procedure, and
what went wrong is written down.
