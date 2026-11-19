---
id: d01-starts-from-greenfield-default
title: "D1. The repository starts from the greenfield default and follows its specification"
is_source_of_truth: true
derives_from: [decisions]
status: current
decision: D1
date: @@DATE@@
decision_status: accepted
built: yes
tags: [process]
supersedes: []
superseded_by: []
amends: []
amended_by: []
---

# D1. The repository starts from the greenfield default and follows its specification

- **Context:** A new repository needs documents, gates, a backlog, and a way of reviewing
  work before any of its own design exists. Writing those by hand each time produces
  repositories that differ for no reason and agents that must relearn each one.
- **Decision:** The repository was created from the greenfield default repository,
  version @@GREENFIELD_VERSION@@ (`.greenfield-stamp` holds the exact source commit). It
  follows [greenfield/specification.md](../greenfield/specification.md). The files that
  specification calls greenfield-owned are not edited here. A rule that does not suit
  this project is departed from by a later decision that amends this one and states the
  owner, the reason, and what would end the departure.
- **Rationale:** One starting state means an agent that knows one of the owner's
  repositories knows where things are in all of them. Keeping the placed policy unedited
  means a later version of greenfield can be compared with it.
- **Rejected:** Starting empty and adding conventions as needed (each repository drifts,
  and the decision log outgrows one file before anyone splits it). Referring to the policy
  in another repository without a copy (an agent in a sandbox cannot read it).
- **Consequences:** The first work is the two steps in
  [greenfield/start-here.md](../greenfield/start-here.md): the language toolchain, then the
  design with [adversarial review](../glossary.md#adversarial-review) throughout.
  Implementation does not begin before the design exit gate.
