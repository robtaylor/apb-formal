# Plan — Real-RTL proof: libfpga `apb_splitter`

**Status:** Proposed (2026-06-22). First real third-party-RTL validation of the `fapb` checker.

## Goal

Prove (or find deviations in) libfpga's `apb_splitter` — a 1-to-N APB address decoder — against
the `fapb` protocol checker on **all** its interfaces, using the open-source SymbiYosys flow.
This exercises the checker on real RTL it did not author, and is the prerequisite step before
deciding whether a separate bridge transaction-accounting checker is worth building.

## Prerequisites

- Milestone-1 complete: `fapb.sv` proven on the golden Completer; `make prove/cover/negtest` green.
- `apb_splitter.v` + its one dependency `onehot_mux.v` (libfpga, WTFPL) available.

## The core problem this plan solves

`apb_splitter` is **multi-interface**: one upstream APB **Completer** port (`apbs_*`) and N
downstream APB **Requester** ports (`apbm_*`). A clean proof must attach the checker in
*different roles on different ports simultaneously*:

- on `apbs_*`: Completer-checker — **assume** a legal upstream Requester, **assert** the
  splitter's upstream-completer obligations (`apbs_pready/prdata/pslverr`);
- on each `apbm_*`: Requester-checker — **assert** the splitter's downstream-requester
  legality, **assume** the (absent) downstream Completers respond legally.

The current checker selects its role by **compile-time define** (`FAPB_REQUESTER`), so two roles
can't coexist in one elaboration. That is the one real blocker.

## Workstreams

### WS-A — Parameter-selected checker role  *(amends ADR 0003)*

Replace the compile-define role flip with a module **parameter** `F_OPT_ROLE`
(`0 = COMPLETER_CHECK`, `1 = REQUESTER_CHECK`). Inside the clocked blocks, select per property:

```systemverilog
// Requester-driven property `rp`, Completer-driven property `cp`:
if (F_OPT_ROLE == REQUESTER_CHECK) begin assert (rp); assume (cp); end
else                               begin assume (rp); assert (cp); end
```

`F_OPT_ROLE` is an elaboration-time constant, so Yosys resolves the `if` statically — multiple
instances with different roles coexist cleanly. The `assume`/`assert` **split decision of
ADR 0003 is unchanged**; only the *selection mechanism* changes → amend ADR 0003 in place
(Status line + `## Amendment` block; the macros in `apb_if.svh` are retired or kept as thin
wrappers over the default param).

- **Deliverables:** updated `formal/fapb.sv`, `rtl/apb_if.svh`; amended ADR 0003.
- **Regression (exit gate):** `completer.sby` (default `F_OPT_ROLE=COMPLETER_CHECK`) still PASSES
  by k-induction; `negtest` still catches the injected bug. No behavior change on existing proofs.

### WS-B — Vendor the DUT (WTFPL)

Copy `apb_splitter.v` and `onehot_mux.v` into `third_party/libfpga/` with a `NOTICE` recording
the upstream repo, commit hash, and WTFPL license.

- **Why vendor, not submodule:** two tiny WTFPL files; vendoring pins an exact snapshot and keeps
  CI hermetic (no network/submodule init). Submodule rejected as heavyweight for this.
- **Deliverable:** `third_party/libfpga/{apb_splitter.v,onehot_mux.v,NOTICE}`.

### WS-C — Multi-interface proof harness

`formal/splitter_check.sv` (parameterized `N_SLAVES=2`, with concrete `ADDR_MAP`/`ADDR_MASK`):

- Free top-level inputs: `PCLK`, `PRESETn` (the splitter is *combinational* — clock/reset only
  drive the checkers and give the temporal frame), the upstream Requester signals, and the N
  downstream Completer responses (`apbm_pready/prdata/pslverr`).
- Instantiate `apb_splitter`; slice the packed `apbm_*` vectors per downstream port.
- 1× `fapb` (COMPLETER_CHECK) on `apbs_*`; N× `fapb` (REQUESTER_CHECK) on each `apbm_*` slice.
- Reset bootstrap (`initial assume(!PRESETn)`) as in the existing harness.
- `formal/splitter.sby` with `prove` + `cover` tasks; vendored files in `[files]`.

- **Deliverable:** wrapper + sby; `make splitter` target.

### WS-D — Run, interpret, iterate (honest outcomes)

Run `prove` + `cover`. Anticipated outcomes, each with a defined response:

- **Likely real finding — `PSLVERR`/decode not gated by select.** The splitter drives
  `apbs_pslverr = ~|decode_mask || |(decode_mask & apbm_pslverr)` and
  `apbs_pready = ~|decode_mask || …` **combinationally from `PADDR` alone**, *not* gated by
  `PSEL`/`PENABLE`. So on a non-matching address while **idle** (`!PSEL`), `apbs_pslverr` is
  HIGH — which trips catalog **P13** (`PSLVERR ⇒ PSEL&&PENABLE&&PREADY`). Per spec §3.4 this is a
  *recommendation* ("recommended… driven LOW otherwise"), not a hard requirement — a consumer
  only samples `PSLVERR` in the completing cycle. **Response:** introduce `F_OPT_SLVERR_STRICT`
  (already foreshadowed by catalog P14): default the hard proof to the *required* semantics
  (PSLVERR meaningful only in the completing cycle, no obligation when idle) so the splitter
  PASSES, and report the ungated drive as a documented **recommendation-level deviation** (a
  spike or a note in `docs/spec/property-catalog.md`). This is exactly the kind of grounded,
  honest finding the checker exists to produce.
- **Expected PASS elsewhere:** downstream requester legality follows from assumed upstream
  legality (P7 keeps `PADDR` stable ⇒ `decode_mask` stable ⇒ downstream setup/access sequence
  legal); upstream bounded-stall (L1) follows from the assumed downstream bounded-stall.
- **If a genuine hard violation appears:** capture the SBY counterexample VCD, minimize, and
  record it as a finding (this would be a real libfpga bug, worth reporting upstream).

- **Deliverable:** PASS on the required-semantics proof; all covers reachable; the ungated-PSLVERR
  observation documented; any counterexample traced.

### WS-E — Wire in + document

- Add `splitter` to `make all` and the CI workflow.
- Update `docs/plans/apb-formal-roadmap.md` (WS3.2 → done) and `CHANGELOG.md`.
- If `F_OPT_SLVERR_STRICT` changes default P13 semantics, update `docs/spec/property-catalog.md`
  and note it in ADR 0002 or a short new ADR.

## Exit criteria

- [ ] `fapb` role is parameter-selected; existing `prove`/`cover`/`negtest` still green (WS-A).
- [ ] `apb_splitter` proof PASSES under required `PSLVERR` semantics; covers reachable (WS-C/D).
- [ ] The ungated-`PSLVERR` recommendation deviation is documented (WS-D).
- [ ] Splitter proof runs in `make all` + CI (WS-E).

## Out of scope (next decision, per request)

A **bridge transaction-accounting checker** (the layer that *would* catch the libfpga
`ahbl_to_apb` double-transaction bug — see `docs/spikes/protocol-checker-catches-bridge-bug.md`)
is **not** part of this plan. Evaluate it *after* this proof lands, when we know how the
checker behaves on real routing RTL and whether the role-parameter generalization makes a bridge
checker cheap to add.
