# ADR 0005 — A minimal AHB-Lite environment for bridge transaction-accounting

**Status:** Accepted (2026-06-22).

**TL;DR.** In the context of catching the libfpga `ahbl_to_apb` double-transaction bug (which the
APB *protocol* checker provably cannot — `docs/spikes/protocol-checker-catches-bridge-bug.md`),
facing the fact that an APB-only model has no notion of "how many transfers the upstream master
intended", we bring a **minimal, model-based AHB-Lite environment** into scope and add a
**transaction-accounting** property, accepting that this extends ADR 0002's APB-only boundary for
bridge DUTs only.

## Context

The APB checker (`fapb`) proves an interface speaks legal APB. The `ahbl_to_apb` bug is *functional*:
one AHB-Lite store yields **two** APB write transactions, each individually protocol-legal. To
catch it we must relate APB transactions to AHB-Lite transfers — which requires modelling the AHB
side. ADR 0002 deliberately scoped AHB/AXI out for the *APB protocol model*; this ADR carves a
narrow exception for *bridge* DUTs.

The decisive subtlety (from the reproducer, `/Users/roberttaylor/Code/libfpga-ahbl-to-apb-bug`):
the double-transaction is only distinguishable from a *legitimate* back-to-back same-address
request if the checker knows the master is **registered-output** (it holds the old address phase
for one cycle after `HREADY` rises, but does not intend a second transfer). A free AHB master
constrained only by AHB-Lite protocol assumptions would be *allowed* to issue that second transfer,
so a naive "count `HTRANS&&HREADY` vs APB transactions" checker would see two legal transfers and
miss the bug.

## Decision

1. **Model, not assume.** Encode the environment as a small **symbolic registered-output AHB-Lite
   master** (`formal/ahbl_master_model.sv`) — a closed FSM with registered outputs, mirroring the
   reproducer's Hazard3-like stub — whose *only* free inputs are per-transfer choices (go / address
   / read-write / write-data). AHB-Lite single-transfer legality is structural (the FSM holds the
   address phase until `HREADY`, then updates one cycle later). This makes "intent" well-defined:
   one `launch` pulse per transfer the master commits.
2. **Accounting property.** `balance = (#launches) − (#APB transactions completed)`; assert
   `balance ≥ 0` (the bridge never produces more APB transactions than the master intended) and a
   small upper bound for state-finiteness. The double-transaction drives `balance` negative.
3. **Reuse `fapb`** (Requester role, `F_OPT_LIVENESS=0`) on the bridge's APB port so the proof also
   confirms the bridge speaks legal APB.
4. **Validate both ways:** prove the property fails (counterexample) on the vendored buggy
   `ahbl_to_apb.v`, and holds on the authored fix `ahbl_to_apb_safe.sv` (README's S_POSTWR/S_POSTRD
   bubble).
5. **Scope stays minimal:** single (non-burst) transfers; no AHB-Lite protection/burst/AXI. This is
   *not* a general AHB-Lite protocol checker.

## Alternatives considered

- **Full AHB-Lite protocol checker (`fahbl`) + free master + assumptions** — rejected for now:
  materially larger (pipelined two-phase, `HREADY`, `HTRANS`/`HBURST`/`HSIZE`), and the bug hinges
  on registered-output *intent*, which a pure-protocol assumption set does not capture (it would
  permit the second transfer, masking the bug). A model encodes intent directly and is far smaller.
- **Stay APB-only (don't catch the bug)** — rejected: the user explicitly wants this class of bug
  caught end-to-end; the spike already documents that the protocol checker cannot.

## Consequences

- The project gains an end-to-end "catches a real bug" result: `make bridge` fails-as-intended on
  the real libfpga RTL and passes on the fix.
- AHB-Lite now appears in the repo, but only as a *minimal model* for bridge accounting — the core
  APB model (ADR 0002) is unchanged.
- **Cost:** the master model is bridge-shaped (single transfers, registered-output). A different
  master class (combinational-output, or bursting) would need a different/extended model.

## Walk-back options

- **If a general AHB-Lite checker is later needed** — promote the model to a proper `fahbl`
  assume/assert checker (its own ADR), and reduce this model to a thin wrapper.

## Links

- `docs/plans/bridge-accounting-checker.md` — the plan.
- `docs/spikes/protocol-checker-catches-bridge-bug.md` — why the protocol checker can't catch it.
- ADR 0002 — APB-only scope this narrowly extends; ADR 0003 — the `fapb` checker reused here.
