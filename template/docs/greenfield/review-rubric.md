---
id: review-rubric
title: Adversarial review rubric
is_source_of_truth: true
derives_from: [greenfield-specification]
status: policy
---

# Adversarial review rubric

What a [reviewer](../glossary.md#reviewer) looks for in an
[adversarial review](../glossary.md#adversarial-review). How a review is requested, recorded,
and acted on is in [adversarial-review.md](adversarial-review.md). This file is given to the
reviewer whole.

## 1. How the rubric is applied

- **No severity.** A reviewer does not grade, rank, or filter. Every
  [finding](../glossary.md#finding) is reported. There is no cut below which a finding is
  dropped. What is done about a finding is decided afterwards, by different rules and by
  someone else ([adversarial-review.md §7](adversarial-review.md#7-triage-and-disposition)).
- **A finding states a consequence.** It names something that goes wrong, or a stated rule
  or document that is contradicted, and gives the evidence. An opinion or an alternative
  that is not wrong has no consequence to state; it goes under Remarks in the record, where
  it is kept but not tracked. When unsure which it is, report a finding.
- **One finding, one primary axis.** An issue often touches several axes (a command
  injection is Security and Correctness). File it once, on the axis that best names the
  harm, and list the others in the finding's `also` field. Do not file it twice.
- **Effect, not intent.** Every axis is judged by what the work does and risks, not by
  what its author meant. The one exception is Scope and malice, which weighs whether an
  addition looks deliberate.
- **Two passes.** The [per-item pass](../glossary.md#per-item-pass) judges one
  [item](../glossary.md#item) on the eight axes of §2. The
  [cross-item pass](../glossary.md#cross-item-pass) judges everything completed so far, as
  one body of work, on the six axes of §3. A review request says which passes to run.
- **Design and code.** The axes apply to a design document as they apply to code. Each
  axis below says what it means for a design. Where an example names code and the item is a
  design, look for the design that would produce that code.
- **Facts for triage.** A reviewer records what a finding touches (§4). That is a
  statement about structure, not a grade.

## 2. Per-item axes

Run on every item reviewed.

### 2.1 Completeness

*Was the item's stated scope addressed?*

Look for:

- a required part not attempted;
- a stub on the main path (`NotImplementedError`, `TODO`, an empty section) that the rest
  depends on;
- a configuration value, flag, schema, or interface that is added and never wired to
  anything that uses it;
- a required sub-aspect of the main path left out (required input validation, a required
  error path) although the feature exists;
- a secondary required aspect missing.

In a design: a required question left unanswered or answered with a placeholder; a
component with no owner; an interface named but not specified; a guess written around an
open question.

Missing required tests belong to Verification integrity. Missing required documentation
belongs to Documentation.

### 2.2 Correctness

*Does in-scope behavior produce right results and leave existing behavior intact?*

Look for:

- behavior opposite to what was specified;
- wrong data returned or stored with no error;
- a regression: a broken build, a broken existing test, a removed migration something
  depends on, a broken public contract;
- a wrong result on a real input path (off by one, wrong operator, inverted edge);
- state that leaks between calls; an asynchronous result never awaited;
- a likely regression that follows from a changed shared signature, even where the tests
  passed;
- a wrong result on a narrow edge; numeric imprecision near a tolerance.

In a design: two statements that cannot both be true; a flow that cannot produce the stated
outcome; an invariant the described mechanism does not uphold; a stated fact about an
external tool or system that is false.

### 2.3 Security

*Does the item introduce a vulnerability? Judge by who can reach it and what they gain.*

Look for:

- injection reachable from untrusted input (SQL, command, code execution);
- an authentication or authorization bypass (an unverified token, a sensitive operation
  with no permission check);
- a credential that is live, or a placeholder or test secret, committed;
- unsafe deserialization, path traversal, cross-site scripting, server-side request
  forgery, hand-rolled or weak cryptography, disabled certificate verification,
  predictable tokens;
- secrets or personal data written to logs;
- a missing layer of defense (a secret compared in non-constant time, permissive
  cross-origin rules, a missing security header);
- a hardening step with a concrete sink that was not taken.

In a design: a trust boundary that is missing or drawn in the wrong place; a threat the
[threat model](../threat-model.md) names with no response, or a response that does not
answer it; an actor trusted with more than its role needs; untrusted input reaching a
decision with nothing stated about how it is validated.

State who can reach the weakness and what they need to do so. That is evidence, not a
grade.

### 2.4 Verification integrity

*Are the tests honest and load-bearing? Is a gate being gamed?*

Look for:

- an existing test weakened, deleted, or skipped, or an assertion removed, so that a gate
  passes;
- a gate made to pass without running what it names;
- required tests that are missing;
- a new test that asserts the wrong thing or passes whatever the behavior is;
- a test that mocks so much that the real path never runs;
- a test that exercises a copy of the subject written inside the test;
- a test with no negative control, so that nothing shows it can fail;
- a flaky or brittle test (dates, ordering, machine-specific values);
- tests of the happy path only where edges were required.

In a design: a claim with no stated way to verify it; an end-to-end scenario that the
[sandbox testing](../sandbox-testing.md) plan cannot run; a stub so unlike the real thing
that a pass says nothing; a security control with no test that attacks it.

### 2.5 Scope and malice

*Did the item do only what was asked? Is there hidden or unrequested behavior?*

Look for:

- a backdoor, a hidden credential check, data sent somewhere it was not meant to go, or a
  capability unrelated to the item;
- an unrequested change that matters to security (a new network call, wider permissions);
- an unrequested refactor of unrelated code;
- a new third-party dependency with no stated need;
- a large diff that reformats code the item did not need to touch;
- incidental cleanup beside the change.

In a design: a capability, component, or data flow that the stated goal does not require;
MVP scope that grew without a decision; an instruction placed in a document that would
steer a later agent toward something the owner did not ask for.

This is the one axis where intent is weighed. Say what makes an addition look deliberate
or accidental; do not assert intent as fact. A vulnerability with no sign of intent
belongs to Security. Malice split across several items cannot be seen here by construction;
it is a cross-item axis (§3).

### 2.6 Maintainability

*Is the item more convoluted than its job needs? Does it break a convention that can be
cited?*

Look for:

- a violation of a convention that is written down (this repository's specification,
  `AGENTS.md`, a named contract): cite the rule;
- structure so tangled that it is itself a risk to correctness;
- one unit that does everything; copied code that should be shared; more machinery than
  the need calls for;
- a file over the size budget, or grown without a split by responsibility;
- a shared constant, interface, or term restated instead of taken from its owner;
- magic numbers, unreadable cleverness, dead code, poor names.

In a design: one fact given two homes; a document that restates another instead of linking
to it; a component whose responsibility cannot be said in a sentence; a design that is
harder to change than its requirements justify.

### 2.7 Documentation

*Are comments, docstrings, contracts, and documents correct and present?*

Look for:

- a contract or public interface document that is wrong, or was not updated to match the
  behavior, where convention requires it;
- a comment or docstring that states the opposite of the code;
- a required document, section, or docstring that is missing;
- planned behavior written in the present tense as though it were built;
- a decision made in the work and not recorded; an open question hidden as a settled one;
- a link that does not resolve to real content; a glossary term used with a meaning other
  than its definition, or a load-bearing term used and not defined;
- unclear wording, a stale reference to something removed, an example that will not run,
  a typo a user will see.

In a design: the same, for the design documents themselves, and front matter that
misstates a document's authority or status.

### 2.8 Reliability

*How does the item behave under concurrency, load, failure, and retry? Can it destroy
data?*

Look for:

- a risk of irreversible data loss: a destructive migration with no backup, a removal
  whose target can be an empty or wrong variable, an operation that corrupts when retried;
- a race or a deadlock; a check followed later by a use of what was checked;
- growth with no bound: a memory leak, a query per row, quadratic work over unbounded
  input, a blocking call inside an event loop;
- a leaked handle or connection; a missing timeout; retries with no backoff;
- a large file loaded when it need not be; work repeated inside a hot loop;
- a small inefficiency on a path that is cold or provably bounded.

In a design: a failure with no stated handling; an operation with no stated behavior on
retry or interruption; state with no stated owner or lifetime; a limit that is needed and
not set.

## 3. Cross-item axes

Run over the whole body of completed work at the reviewed commit, not over one item's
change. A reviewer running this pass reads the design documents and everything built so
far. A failing test suite does not end the pass early. A reviewer of a single item cannot
judge these axes, because each needs the assembled picture.

| Axis | What it catches | Why the per-item pass cannot |
|---|---|---|
| **Consistency** | Names, patterns, and contracts that do not agree across items; pieces that no longer fit together; a document and the thing it describes drifting apart. | Each item looks fine alone. |
| **Composed security** | A vulnerability made of parts: a source added by one item and a sink added by another; a boundary each item respects and the combination crosses. | No single change is exploitable. |
| **Distributed malice** | A hostile capability assembled across items, each of which looks harmless. | This is the evasion designed against per-item review. |
| **Style coherence** | Style or lint practice that is consistent inside each item and drifts between items or away from the project. | Drift only shows across items. |
| **Coverage adequacy** | Whether the tests, taken together, cover the behaviors, edge cases, and assumptions of the whole body of work. | Coverage can be fine for each item and thin overall. |
| **Contract coherence** | Whether stated assumptions, behaviors, and capabilities still match across design, code, tests, and any script contract. | Drift builds up across items. |

In a design: Consistency covers the documents against one another (design, threat model,
sandbox testing, decisions, glossary, backlog). Coverage adequacy asks whether every MVP
scenario and every threat response has a planned test. Contract coherence asks whether
each decision is reflected in the documents it changes.

**Distributed malice.** The threat is an agent with write access, reliably wrong or
compromised, that splits an unwanted addition across several items so that no single
change looks like more than an accident. Per-item review cannot catch this. The cross-item
pass is the only defense, so it is run with the strongest reviewer available and under
this instruction: assume the body of work may have been assembled to evade review of its
parts. Trace what the parts do together. Follow data from every place it enters to every
place it leaves or takes effect.

**Earlier reviews.** The cross-item pass also checks the review trail: that no earlier
review record has changed since it was committed, that every earlier finding has a
[disposition](../glossary.md#disposition), and that each finding left for later is
still tracked. A reviewer may file a finding against a disposition (for example, a
finding left for later that touches an interface).

## 4. Values a finding uses

The record format that carries these is in
[adversarial-review.md §6](adversarial-review.md#6-the-review-record).

**`axis`** takes one of these values. **`also`** takes `none`, or one or more of them
separated by commas.

| Value | Axis | Pass |
|---|---|---|
| `completeness` | Completeness | per-item |
| `correctness` | Correctness | per-item |
| `security` | Security | per-item |
| `verification-integrity` | Verification integrity | per-item |
| `scope` | Scope and malice | per-item |
| `maintainability` | Maintainability | per-item |
| `documentation` | Documentation | per-item |
| `reliability` | Reliability | per-item |
| `consistency` | Consistency | cross-item |
| `composed-security` | Composed security | cross-item |
| `distributed-malice` | Distributed malice | cross-item |
| `style-coherence` | Style coherence | cross-item |
| `coverage-adequacy` | Coverage adequacy | cross-item |
| `contract-coherence` | Contract coherence | cross-item |
| `other` | None of the above fits. Say why in the observation. | either |

**`touches`** lists every structural element the finding's resolution would change. It is
what makes a fix costly once other work is built on top.

| Value | The resolution would change |
|---|---|
| `interface` | A public or shared interface: a command line, an API, a signature other components call. |
| `data-format` | A schema, a file format, a wire format, or a configuration format. |
| `persisted-data` | Data that is stored and would need migrating. |
| `trust-boundary` | A trust boundary, a split of privilege, or an assumption of the threat model. |
| `component-boundary` | How the system is divided into components, or who owns a shared thing. |
| `test-harness` | The end-to-end test harness, its stubs, or its synthetic data. |
| `core-dependency` | A language, a runtime, or a dependency the design is built around. |
| `local` | None of the above: the resolution stays inside one section, one module, or one test. |

`local` is never combined with another value.
