# G005 Wider documentation lint in the template

- **State:** open.
- **Depends on:** nothing; G001 is a good model for it.
- **Owner:** Bryant Quist.

## Deliverable

Checks, placed by the template and run by `docs-lint`, for what Glossarian does not
cover:

1. ordinary relative Markdown links resolve to a file, and a `#fragment` to a heading in
   it;
2. every authoritative document has the front matter keys the specification requires
   (§3.1), with `status` from its vocabulary, and no two documents share an `id`;
3. every ID in a `derives_from` list is the `id` of a document that exists;
4. a backlog item has the form `backlog/README.md` gives.

## Why

The specification says links "MUST resolve to real content", and no gate checks it. The
evidence for the template is one check made by hand on 2026-11-18: file targets by a
one-off shell loop, anchors by reading. A renamed heading in `start-here.md` would break
links in six backlog items and nothing would report it.

## Implements or updates

- `template/Makefile`, `template/docs/greenfield/specification.md` §3.9 and §6.1.
- `VERSION`.

## Done when

The checks run on a fresh stamp in `make template-check`, each with a planted defect it
must report, and the trio is reviewed and ratified.
