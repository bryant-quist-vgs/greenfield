# @@PROJECT_NAME@@

> **GREENFIELD-STUB** Say in two or three sentences what this project is and who it is for,
> once `docs/design.md` §1 is written. Then say how to install and use it, when there is
> something to install. (Backlog B002 writes the first part; B001 writes "Working here".)

**Status on @@DATE@@:** new. Nothing is designed or built. The repository holds the default
documents and gates that greenfield places;
[docs/greenfield/start-here.md](docs/greenfield/start-here.md) says what to do first.

## Working here

The [operator](docs/glossary.md#operator) runs `make install-linters` (an agent hands it
over). It installs glossarian and llm-size-guard at the commits pinned in the `Makefile`.

```bash
make help                                        # lists the quality gates
make change-log-entry TITLE="..." TAGS="..."     # creates the change log entry of a change
make commit                                      # every gate except format; run before committing
```

`make commit` regenerates `docs/change_log.md`, and can merge the upstream branch into a
working tree that has no uncommitted change:
[docs/greenfield/change-log.md](docs/greenfield/change-log.md).

Agents start at [AGENTS.md](AGENTS.md). The design is in [docs/design.md](docs/design.md),
and the work to be done is in [backlog/](backlog/).
