---
id: threat-model
title: Threat model
is_source_of_truth: true
derives_from: [design, glossary]
status: draft
---

# Threat model

What @@PROJECT_NAME@@ protects, from whom, and how. This is the home of the trust
boundaries and of every threat the design answers; [design.md](design.md) summarizes and
links here. Terms are defined in the [glossary](glossary.md#definitions). Sections marked
with a [stub marker](glossary.md#stub-marker) are not yet written; backlog B003 writes
them.

## 1. Assets

> **GREENFIELD-STUB** List what is worth protecting, each with an ID (`A-1`, `A-2`): data,
> credentials, the integrity of an output, the availability of a service, the operator's
> machine. Say what harm follows if each is lost, changed, or disclosed.

## 2. Actors and trust

> **GREENFIELD-STUB** List every party that touches the project, and what each is trusted
> with and not trusted with. Include at least: the owner or operator; each kind of user;
> each external system; and the agents that write this project's code. For the last, keep
> the two rows below and adjust them to the project.

| Actor | Trusted with | Not trusted with |
|---|---|---|
| [Working agent](glossary.md#working-agent) | Proposing changes on a branch. | Being right, or being uncompromised. Its changes take effect only through the gates and review. |
| [Reviewer](glossary.md#reviewer) | Reporting findings at a commit. | Changing the repository. |

## 3. Trust boundaries

> **GREENFIELD-STUB** Name each place where data or control passes from a less trusted
> party to a more trusted one, each with an ID (`TB-1`, `TB-2`). For each: what crosses it,
> and what is checked as it crosses.

## 4. Threats and responses

> **GREENFIELD-STUB** One row for each threat. A response is a mechanism in the design, not
> an intention. Every response names the test that attacks it, or the backlog item that
> will add that test.

| ID | Threat | Asset | Boundary | Response | Verified by |
|---|---|---|---|---|---|
| T-1 | A change that looks harmless adds a hostile capability, in one piece or split across several changes. | The integrity of the project. | The merge to the default branch. | Every change passes `make commit`; reviews use the Scope and malice axis and the cross-item Distributed malice axis ([greenfield/review-rubric.md](greenfield/review-rubric.md)). | The review records under `reviews/`. |

## 5. Not defended

> **GREENFIELD-STUB** List the threats this design does not answer, and why: outside the
> boundary, accepted by the owner, or deferred. Link each to its entry in
> [out-of-scope.md](out-of-scope.md) or [deferred-work.md](deferred-work.md), or to the
> decision that accepts the risk.

## 6. Assumptions

> **GREENFIELD-STUB** List what the model takes as given (for example: the operator's
> machine is not already compromised; a named dependency behaves as documented). An
> assumption that fails makes the responses above unreliable, so each one is specific
> enough to be checked.
