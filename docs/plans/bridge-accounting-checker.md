# Plan — AHB-Lite→APB bridge transaction-accounting checker

**Status:** Done (2026-06-22). Catches the libfpga `ahbl_to_apb` double-transaction bug on the
real RTL and proves the fix; runs in `make all`. Delivered on branch
`feat/bridge-accounting-checker` (PR).

## Goal

Catch the class of bug the APB *protocol* checker provably cannot — the `ahbl_to_apb`
double-transaction (one AHB-Lite store → two APB writes) — by relating APB transactions to the
upstream master's *intent*, and prove the documented fix removes it.

## Why a model, not assumptions

The double-transaction is only distinguishable from a *legitimate* back-to-back same-address
request if the checker knows the master is **registered-output** (holds the old address phase one
cycle past `HREADY`, without intending a second transfer). A free AHB master + protocol
assumptions would *permit* that second transfer and miss the bug. So the environment is a
**model**, not an assumption set. Full rationale + alternatives: [ADR 0005](../adr/0005-ahbl-bridge-accounting.md).

## What shipped

| Workstream | Deliverable | Status |
|---|---|---|
| WS-A | ADR 0005 (minimal AHB-Lite env in scope) | ✅ |
| WS-B | Vendored buggy `ahbl_to_apb.v`; authored `ahbl_to_apb_safe.sv` (README S_POSTWR/S_POSTRD bubble) under `third_party/libfpga/` | ✅ |
| WS-C | `formal/ahbl_master_model.sv` — symbolic registered-output AHB-Lite master (lifted from the reproducer TB); emits a `launch` pulse per intended transfer | ✅ |
| WS-D | `formal/bridge_check.sv` — `balance = launches − APB completions`, assert `≥ 0`; plus an `fapb` (Requester role) APB-legality check. `formal/bridge.sby` tasks `buggy`/`safe` | ✅ |
| WS-E | `make bridge` in `make all` + CI; docs | ✅ |

## How it works

- `balance` increments on each `launch` (master intent), decrements on each APB completion
  (`PSEL && PENABLE && PREADY`). `assert(balance >= 0)` means *no APB transaction the master did
  not intend*. The double-transaction makes a second APB completion arrive for one `launch`,
  driving `balance` to −1.
- **buggy** task (`smtbmc` BMC): fails with a counterexample (`expect fail` → green). The failing
  assert is `bal >= 0` at `bridge_check.sv`.
- **safe** task (`abc pdr`): k-induction does not close without a hand-written invariant relating
  `balance` to the master/bridge FSM states, so PDR/IC3 discovers the inductive invariant
  automatically — *Property proved*.

## Verification

```sh
make bridge          # buggy -> FAIL (caught, expect fail); safe -> PASS (PDR). Exit 0.
make all             # whole suite incl. bridge.
```

## Limits / next steps

- Single (non-burst) transfers; zero-wait APB completer (`pready=1`), matching the reproducer.
  A free APB completer + `fapb`-assume, and AHB bursts, are possible extensions.
- The master model is registered-output (Hazard3-class). A combinational-output master would not
  trigger the bug and would need a different model.
- This is not a general AHB-Lite protocol checker — see ADR 0005 walk-back.
