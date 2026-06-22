# Plan — apb-formal: build the APB-lite compliance checker

**Status:** Active. 2026-06-22 — Phase 0 (scaffolding) in progress; decisions ratified in
ADRs 0001–0004.

## Goal

Deliver a reusable SystemVerilog `assume`/`assert` **APB protocol-compliance checker**
(`formal/fapb.sv`), proven with SymbiYosys, grounded in a machine-readable capture of
IHI0024E, and validated against real open-source APB RTL — including catching a known real
bridge bug.

## Prerequisites

- ADR 0001 (toolchain), 0002 (scope), 0003 (deliverable shape), 0004 (waveform format) — all
  Accepted.
- Toolchain present: `yosys 0.64`, `sby v0.64`, `nix`, `dot`; `wavedrom-cli` via `npx`.

## Where things stand (2026-06-22)

Repo initialized; four-document discipline scaffolded; ADRs 0001–0004 written; this plan
migrated in. Next: finish Phase 0 commit, then Phase 1 spec capture.

## Workstreams

### WS0 — Scaffolding & decisions  *(~0.5 day)*

**Status:** In flight.

- WS0.1 `git init`; discipline docs; `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `.gitignore`. **Done.**
- WS0.2 ADRs 0001–0004 + index. **Done.**

**Exit:** `docs/` skeleton + 4 Accepted ADRs + this plan committed.

### WS1 — Spec capture  *(~1.5 days)*

**Status:** Pending.

- **WS1.1** `docs/spec/IHI0024E.md` — full structured markdown; tables rebuilt as GFM (signal
  descriptions, validity rules App A, signal matrix App B, check signals).
- **WS1.2** `docs/spec/waveforms/` — Fig 3-1/3-2/3-4/3-5/3-6/3-7 → WaveDrom JSON5 + rendered SVG;
  state machine (Fig 4-1) → Graphviz `.dot` + state table. Each annotated with T-cycle phase labels.
- **WS1.3** Dependency finding: APB-lite is self-contained; AXI (IHI0022) & RME (DEN0129) are
  cited only for bridge error-mapping / RME, both out of scope — recorded, not fetched.
- **WS1.4** `docs/spec/property-catalog.md` — de-duplicated ~21-item catalog: property → spec
  citation → APB revision → in-scope? → checker-side (assume/assert).

**Exit:** spec MD complete; all in-scope waveforms render to SVG; every catalog row cites a spec location.

### WS2 — The checker  *(~2–3 days)*

**Status:** Pending. Depends on WS1.4.

- **WS2.1** `rtl/apb_if.svh` — parameterized interface (`ADDR_WIDTH`, `DATA_WIDTH`,
  `F_OPT_SLVERR`, `F_OPT_PSTRB`, `F_OPT_PPROT`).
- **WS2.2** `formal/fapb.sv` — immediate-assertion checker, `SLAVE_ASSUME`/`SLAVE_ASSERT`
  macro-flip (per ADR 0003). Properties from the catalog; `cover` for read/write/wait/error/back-to-back.
- **WS2.3** `rtl/apb_completer_ref.sv` — minimal compliant Completer (register file, wait states,
  RO/WO regs) to self-test the checker.
- **WS2.4** *(stretch)* `rtl/apb_requester_ref.sv`.

**Exit:** `fapb.sv` elaborates under Yosys `read_verilog -sv`; every in-scope catalog row has an
assertion; every named scenario has a `cover`.

### WS3 — Proofs, validation, CI  *(~1.5 days)*

**Status:** Pending. Depends on WS2.

- **WS3.1** SBY wrappers (instantiation, not `bind`) + `Makefile` (`prove` k-induction, `cover`, `all`).
- **WS3.2** Validate against real RTL: bind to libfpga `apb_splitter` / a DOOMSoC regblock (prove
  compliant); bind to the libfpga AHBL→APB **bridge-bug reproducer**
  (`/Users/roberttaylor/Code/libfpga-ahbl-to-apb-bug`) and demonstrate the checker **catches** the
  double-transaction defect.
- **WS3.3** GitHub Actions via the pinned nix flake; run `make all`. Watch CI after first push.

**Exit:** golden Completer proves clean; all covers reachable; checker fails (as intended) on the
bridge bug; CI green.

## Phase exit criteria (project milestone 1)

- [ ] Machine-readable spec + property catalog committed (WS1).
- [ ] `fapb.sv` + golden Completer; `make prove` PASS, `make cover` all reachable (WS2, WS3.1).
- [ ] Negative test: checker produces a counterexample on the bridge-bug reproducer (WS3.2).
- [ ] CI green on a clean runner (WS3.3).

## Notes

- Decisions are in `docs/adr/`; this plan schedules, it does not decide. Design detail for the
  protocol lives in `docs/spec/` and (later) `docs/apb-protocol-model.md`.
