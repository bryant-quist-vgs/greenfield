# G003 CI for greenfield

- **State:** open.
- **Depends on:** nothing.
- **Owner:** Bryant Quist.

## Deliverable

`.github/workflows/ci.yml` in this repository that runs `make install-linters` and
`make commit` on `ubuntu-latest` and `macos-latest`, for pull requests and for pushes to
`main`.

## Why

`make commit` is the only gate, and it runs only where someone remembers to run it.
`template-check` on Ubuntu is also the cheapest way to get the evidence G002 asks for.

## Implements or updates

- `Makefile`: the header comment that says there is no CI.
- `README.md`, "Working on greenfield".

## Done when

A run has passed on both operating systems, and the workflow file says so only after
that.
