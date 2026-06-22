# Spike — Will the APB protocol checker catch the libfpga `ahbl_to_apb` double-transaction bug?

**Status:** Resolved (2026-06-22) — NO (by design); the bug is functional, not a protocol
violation. The protocol checker is *necessary but not sufficient*; catching it needs a
bridge-level transaction-accounting property.

## Question

If the `fapb` Requester-checker is bound to the APB output port of libfpga's `ahbl_to_apb`
bridge, will it flag the known double-transaction defect (one AHB-Lite store producing two APB
write transactions)?

## Why this is in question

The roadmap's WS3.2 framed "catch the bridge bug" as the headline real-RTL validation. Before
investing in an AHB-side environment model, confirm the bug is actually expressible as an APB
protocol violation — otherwise the protocol checker is the wrong tool for it.

## Approach

- **Q1 (analysis, cheapest).** Read `ahbl_to_apb.v` and the reproducer
  (`/Users/roberttaylor/Code/libfpga-ahbl-to-apb-bug`, `tb_ahbl_to_apb.v`). Determine whether
  the *second*, spurious APB transaction is itself protocol-legal (clean SETUP→ACCESS→complete).
- **Q2 (only if Q1 inconclusive).** Build an AHB-Lite assumption environment and run the
  Requester-checker against the bridge.

## Findings

- 2026-06-22: `ahbl_to_apb` drives `{psel,penable,pwrite}` purely from its FSM state
  (`S_WR1`=setup `101`, `S_WR2`=access `111`, `S_RD0/1` analogous). Each transaction it emits
  is a textbook two-phase APB transfer.
- 2026-06-22: The defect (per the reproducer README) is that on retire (`S_WR2→S_READY`) the
  FSM re-decodes `aphase_to_dphase` off **stale** `htrans`/`hwrite`, launching a *second*
  `S_WR0…` sequence. That second sequence is **also a fully protocol-legal APB write.**
- 2026-06-22: Therefore the violation is "two APB transactions for one AHB transaction" — a
  *functional/accounting* error, invisible to any property that looks only at APB handshake
  legality. Confirms Q1; Q2 not needed.

## Outcome

The APB *protocol* checker cannot catch this bug, and that is correct: both emitted APB
transactions are individually compliant. Protocol compliance is necessary but not sufficient
for bridge correctness. Catching the double-transaction requires a **bridge-level property**
that relates upstream (AHB) transactions to downstream (APB) transactions — e.g. "each accepted
AHB data-phase produces exactly one APB `PSEL` pulse," or a transaction counter equality. That
is a distinct verification layer (an AHB→APB bridge checker), out of scope for the standalone
APB-lite model (ADR 0002) and a candidate for a future `fahb`/bridge-accounting spike.

**What we did instead** to prove the checker has teeth: a deliberately non-compliant Completer
(`rtl/apb_completer_bad.sv`, violates P13) that the checker catches via SBY `expect fail`
(`make negtest`). See also the deferred real-RTL item below.

## Follow-ups

- Real-RTL validation of `apb_splitter` (libfpga) is **deferred**: it is a multi-interface
  module (one upstream Completer + N downstream Requesters), so a clean proof needs per-instance
  role selection. The current checker selects role by compile-time define (`FAPB_REQUESTER`),
  which can't mix `assume`/`assert` instances in one elaboration. Tracked in
  `docs/plans/apb-formal-roadmap.md` (WS3.2). Cheapest fix: add a `parameter`-selected role so
  multiple `fapb` instances with different roles can coexist.
