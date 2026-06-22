# Spike — Does libfpga `apb_splitter` comply with the APB protocol, and what does the checker find?

**Status:** Resolved (2026-06-22) — YES (compliant under the required semantics); the checker
surfaced one **recommendation-level** deviation: `apb_splitter` drives `PSLVERR`/decode
combinationally from `PADDR`, ungated by `PSEL`.

## Question

Binding the `fapb` checker to libfpga's `apb_splitter` (one upstream Completer port + N
downstream Requester ports), does the real RTL pass, and does the checker reveal anything?

## Why this was in question

First validation of `fapb` on third-party RTL it did not author — the project's grounding
claim. Needed to confirm the parameter-role generalization (WS-A) actually enables a
multi-interface proof, and to learn how the checker behaves on real routing logic.

## Findings (verified)

- 2026-06-22: With the multi-interface harness (`formal/splitter_check.sv`: 1× COMPLETER_CHECK
  upstream, 2× REQUESTER_CHECK downstream, `N_SLAVES=2`), **`sby -f formal/splitter.sby prove`
  PASSES by k-induction** and **`cover` reaches every scenario** on both upstream and downstream
  checkers — given a legal upstream Requester and legal downstream Completers (assumed).
- 2026-06-22: The upstream checker required `F_OPT_SLVERR_STRICT=0`. With it set to **1**, the
  proof **FAILS** with a counterexample at the PSLVERR-gating assert (`fapb.sv:118`, catalog
  P13/P14). Root cause in `apb_splitter.v`:
  ```
  assign apbs_pslverr = ~|decode_mask || |(decode_mask & apbm_pslverr);
  assign apbs_pready  = ~|decode_mask || |(decode_mask & apbm_pready);
  ```
  Both are functions of `apbs_paddr` (via `decode_mask`) **only** — not gated by `apbs_psel` /
  `apbs_penable`. So on an address in the unmapped region while the bus is **idle**
  (`!apbs_psel`), `apbs_pslverr` is HIGH. Catalog **P13/P14** ("PSLVERR valid only in the
  completing cycle; recommended LOW otherwise") therefore trips.

## Outcome

`apb_splitter` is **protocol-compliant** for the semantics that matter: a Requester only samples
`PSLVERR` when `PSEL && PENABLE && PREADY`, and in that cycle the splitter's value is correct
(error on decode miss, else the routed slave's). The ungated drive when idle is a deviation from
the spec's §3.4 *recommendation* ("recommended, but not required, that PSLVERR is driven LOW
when PSEL/PENABLE/PREADY are LOW"), **not** a hard violation — so it is not a bug to report
upstream, just a characterisation.

**Decision:** model this distinction with `fapb`'s `F_OPT_SLVERR_STRICT` parameter:
- **default `1`** — enforces the recommendation (used for the golden Completer and the negative
  test, which gate `PSLVERR` correctly);
- **`0`** — drops the recommendation, asserting only the required semantics (used for the
  `apb_splitter` upstream checker).

The proof is wired into `make all` and CI with `STRICT=0` upstream. The pass demonstrates the
checker works on real third-party RTL; the verified strict-mode failure demonstrates it has
teeth and pinpoints exactly where real RTL diverges from the spec's recommendations.

## Follow-ups

- A bridge transaction-accounting checker (the layer that would catch the `ahbl_to_apb`
  double-transaction bug, `protocol-checker-catches-bridge-bug.md`) — to be evaluated next.
