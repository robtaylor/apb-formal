# ADR 0003 — Deliverable: an assume/assert compliance checker (macro-flip), with a golden Completer

**Status:** Accepted (2026-06-22). Mechanism amended 2026-06-22 — role selection moved from a
compile define to a parameter; see Amendment below.

**TL;DR.** In the context of "build a formal model of APB", facing several possible meanings
(abstract spec / golden RTL / property suite), we chose to make the primary deliverable a
**reusable `assume`/`assert` protocol-compliance checker** that flips between a Requester-checker
and a Completer-checker, plus a **small golden reference Completer** to self-test it, to achieve
something bindable to arbitrary APB RTL, accepting that we do not ship a full verified production
peripheral.

## Amendment (2026-06-22) — role selection is a parameter, not a compile define

The original Decision §1 selected the checker role with a compile define (`FAPB_REQUESTER`,
expanded via `SLAVE_ASSUME`/`SLAVE_ASSERT` macros). That cannot check a **multi-interface** DUT
— e.g. libfpga's `apb_splitter` has one upstream Completer port and N downstream Requester ports,
needing a Completer-checker *and* N Requester-checkers in the *same elaboration*, which a single
global define cannot express.

This amendment changes the **mechanism** (the assume/assert *split* decision is unchanged):
role is now the `fapb` module **parameter `F_OPT_ROLE`** (`FAPB_COMPLETER_CHECK` /
`FAPB_REQUESTER_CHECK`, an elaboration-time constant). The `APB_REQ`/`APB_CMP` macros in
`rtl/apb_if.svh` now expand to `if (F_OPT_ROLE == …) assert; else assume;`. Multiple `fapb`
instances with different roles coexist. The default is `FAPB_COMPLETER_CHECK`, so existing
single-DUT proofs are unchanged (regression: `make prove`/`cover`/`negtest` still green).

The original Context, Decision, and Consequences below are retained for historical record. Where
"macro flip via a define" conflicts with this amendment, this amendment wins.

## Context

"Formal model" is ambiguous. The most reusable and highest-leverage artifact is a *checker*: a
property module that encodes the protocol once and can be attached to any APB endpoint to prove
compliance — the role ZipCPU's `fapb_slave.v` plays for APB and `faxil_slave.v` for AXI-Lite.
A checker needs a known-good DUT to confirm it doesn't false-fail, and a known-bad DUT to confirm
it actually catches violations.

## Decision

1. The core deliverable is **`formal/fapb.sv`**: APB protocol properties split by who drives each
   signal, behind `SLAVE_ASSUME` / `SLAVE_ASSERT` macros so the *same file* serves as:
   - a **Completer-checker** — `assume` the Requester-driven signals are legal, `assert` the
     Completer-driven signals (`PREADY`, `PRDATA`, `PSLVERR`) obey the protocol; or
   - a **Requester-checker** — flip the macros.
2. **`rtl/apb_completer_ref.sv`** — a minimal compliant Completer (small register file, optional
   wait states, RO/WO regs to exercise `PSLVERR`) used to self-test the checker: prove no
   assertion is reachable and every `cover` scenario is.
3. A golden reference **Requester** is a stretch goal, not required for the first milestone.

## Alternatives considered

- **Golden reference RTL as the primary deliverable** — rejected as primary: a verified peripheral
  is less reusable than a checker that validates *any* peripheral. The golden Completer is kept,
  but as a checker self-test, not the headline.
- **Abstract protocol spec (state machine + invariants only)** — rejected: doesn't bind to RTL
  (see ADR 0001).

## Consequences

- One property file documents the protocol *and* serves as the executable conformance test for
  both endpoint roles.
- The golden Completer gives an always-on regression: any change that breaks a property shows up
  as a self-test failure.
- **Cost:** the macro-flip discipline must be maintained carefully — a property placed on the
  wrong side (assume vs assert) silently weakens the proof. Mitigated by the property catalog
  tagging each row's checker-side.

## Walk-back options

- **If a verified production Completer/Requester is later needed** — promote the reference RTL to
  a first-class deliverable with its own proofs; the checker becomes its spec.

## Links

- ADR 0001 — toolchain/style the checker is written in.
- ADR 0002 — the signal scope the checker covers.
- `docs/spec/property-catalog.md` — the rows that become assertions, each tagged assume/assert.
