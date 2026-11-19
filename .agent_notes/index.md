# Agent notes

The memory store for agents maintaining greenfield. It is tracked in Git and belongs to no
vendor. `AGENTS.md` sends each session here first. The rules and the form of a note are
the ones greenfield places in every repository:
[template/.agent_notes/index.md](../template/.agent_notes/index.md). Notes here also use
the types `process` and `design`.

Notes are an aid, not an authority. Where a note and the specification disagree, the
specification is right and the note is corrected or deleted.

## Index

- [prose](prose.md): the owner's six rules for every page here and in every placed
  repository; read before writing or editing prose.
- [prose-rule-choices](prose-rule-choices.md): the maintaining agent's readings of the
  prose rules (who runs what, what a record is), not yet confirmed by the owner, and four
  open questions.
- [maintainer-role](maintainer-role.md): the agent is the long-term owner and maintainer
  of the specification, by the owner's word; what that covers and what it does not.
- [owner-requirements](owner-requirements.md): what the owner asked the default
  repository to be, in the owner's terms; the test for any change.
- [design-choices](design-choices.md): seventeen choices in the default repository that
  go beyond what the owner asked for, all confirmed by the owner on 2026-11-18; ask
  before changing one.
- [reference-repositories](reference-repositories.md): outside repositories and documents
  worth reading before a large change, and what each is useful for.
- [sandbox-limits](sandbox-limits.md): what the agent sandbox blocks here, and how the
  gates work inside it.
- [linter-installs](linter-installs.md): the operator runs `make install-linters`; on the
  owner's machine it replaces tools the owner develops, so use the linters on `PATH`.
- [script-reviews](script-reviews.md): what a review of a script trio needs, what
  the reviews of 2026-11-18 did not cover, and what a change to either goes through.
- [review-linter-design](review-linter-design.md): why the review linter is built as it
  is; read before changing `template/tools/review_lint*`.
- [change-log-design](change-log-design.md): twenty choices in the change log, its tags,
  and its script that the owner has not confirmed, each with its reason; ask before
  building on one.
