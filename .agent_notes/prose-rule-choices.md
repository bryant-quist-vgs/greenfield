---
name: prose-rule-choices
description: Readings the maintaining agent made to apply the prose rules (who runs what, what a record is, the word "operator"); the owner has not confirmed them, and four questions are open.
type: owner
date: 2026-11-18
---

The owner's six rules are in [prose](prose.md). Applying them needed the readings below.
Each is the maintaining agent's, made on 2026-11-18. The owner has not confirmed them:
ask before building on one, and correct this note with the answer.

1. **In a placed repository an agent may run** every `make` target except
   `install-linters`, and Git commands that stay on the machine: `git init`, a commit, a
   merge of a commit the clone already holds, a tag. Reason: the review procedure needs a
   commit hash and a `review/R<NN>` tag, the `change-log` gate makes a merge and hands a
   merge with conflicts to the agent, and an agent in a sandbox can do all of these
   without credentials.
2. **In a placed repository the operator runs** `make install-linters`, and anything
   that needs credentials or leaves the machine: a fetch, a push, opening or merging a
   pull request, a release, a change to repository settings.
3. **In greenfield itself the operator also commits.** Reason: the owner has given no
   approval to commit here ([maintainer-role](maintainer-role.md)).
4. **Each list has one home.** For a placed repository:
   `template/docs/greenfield/specification.md` §6.1. For greenfield: the "Who runs what"
   rule in `AGENTS.md`. Every other page links to the home.
5. **"Operator" is a glossary term** in `template/docs/glossary.md`: the person at the
   machine who runs what an agent may not; often, but not necessarily, the owner.
6. **Records, which the rules exempt,** are read as: the "Change log" section of a script
   contract, `docs/decisions.md` with the files under `docs/decisions/`, committed review
   records under `reviews/`, and the change log entries under `docs/change_log/`, from
   which `docs/change_log.md` is generated. The owner named `docs/decisions.md`,
   `docs/changelog.md`, and their log files; the file a placed repository holds is
   `docs/change_log.md`, the name the owner gave it in the request for the change log
   ([owner-requirements](owner-requirements.md), item 10).
7. **"Built against contract vN"** in a script header is read as a reference the
   contract's revision rules require, not as wording relative to a version (rule 4).

Open, for the owner:

- May an agent run `llm-size-guard accept` and `llm-size-guard defer`, which change the
  tracked state of the size gate?
- In pull request 1 of a placed repository (`template/backlog/B001-*.md`), who installs
  the language toolchain?
- May an agent install a tool into `$TMPDIR` with `uv tool install`, as
  [sandbox-limits](sandbox-limits.md) describes for shellcheck?
- The owner's output-cap hook cites `AGENTS.md, "Bash output cap"`; the rule in both
  `AGENTS.md` files is headed "Command output". One of the two names changes.

**How to apply:** when a page must say who runs a command, link to the home in item 4 and
do not restate the list. When the owner answers one of the open questions, move it into
the list above with the date.
