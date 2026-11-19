# G006 The generated change log outgrows the size gate

- **State:** open.
- **Depends on:** the owner's choice between the two ways below.
- **Owner:** Bryant Quist.

## Deliverable

`docs/change_log.md`, the generated list of a placed repository, does not fail
`make llm-size-guard` however many entries the repository holds.

## Why

The generated list gains one line for each entry and one for each date. It reaches the
warning level of the size gate (500 lines) at about 400 entries, and the error level
(800 lines), which fails `make commit`, at about 650. `llm-size-guard` has no way to
leave one file out, and the list is not maintained by hand, so splitting it by
responsibility does not apply.

## Open points

The owner chooses:

- `llm-size-guard` gains a way to leave out a generated file (the owner maintains that
  tool), and the placed `.llm-file-size-guard.toml` names `docs/change_log.md`; or
- `tools/change_log.sh` writes one list for each year, and `docs/change_log.md` links to
  them. That is a new version of the change log contract and changes
  `template/docs/greenfield/change-log.md` §3.

## Done when

`make llm-size-guard` passes in a scratch repository that holds 1,000 entries.
