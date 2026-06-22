# Plan — apb-formal: build the APB-lite compliance checker

**Status:** Active. 2026-06-22 — Phases 0–2 complete and the checker is **proven by
k-induction**; Phase 3 mostly complete (proofs + negative test + CI/flake landed; one
real-RTL item deferred — see WS3). Decisions ratified in ADRs 0001–0004.

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

- **WS0–WS2 done.** Repo + discipline + ADRs; full spec capture + waveforms + property
  catalog; `fapb.sv` checker + golden Completer. `make prove` PASSES by k-induction;
  `make cover` reaches all six scenarios.
- **WS3 mostly done.** Negative test (`make negtest`) proves the checker catches injected
  non-compliance. nix flake + GitHub Actions wired (`make all`). flake.lock pinned.
- **Open finding** (see `docs/spikes/protocol-checker-catches-bridge-bug.md`): the libfpga
  `ahbl_to_apb` double-transaction bug is **functional, not a protocol violation**, so the
  protocol checker correctly does not flag it. Real-RTL proof of `apb_splitter` is **deferred**
  (needs parameter-selected checker role; see WS3.2).
- **Not yet:** golden Requester (WS2.4 stretch); APB4 `PSTRB`/`PPROT` property branches;
  real-RTL `apb_splitter` proof (planned in `apb-splitter-realrtl-proof.md`).

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

**Status:** Mostly shipped (2026-06-22).

- **WS3.1 — Done.** SBY wrappers (instantiation, not `bind`) + `Makefile` (`prove`, `cover`,
  `negtest`, `all`). `completer.sby` (prove/cover tasks), `negtest.sby` (`expect fail`).
- **WS3.2 — Done.** Negative test ships (`rtl/apb_completer_bad.sv` + `make negtest`): the
  checker catches an injected P13 violation. **Real-RTL:** libfpga `apb_splitter` (vendored under
  `third_party/libfpga/`) is **proven compliant** via a multi-interface harness
  (`formal/splitter_check.sv`, `make splitter`) — `make all` runs it. The checker surfaced one
  spec *recommendation*-level deviation (PSLVERR ungated by PSEL), modelled with
  `F_OPT_SLVERR_STRICT` — see `docs/spikes/apb-splitter-pslverr-ungated.md`. The `ahbl_to_apb`
  double-transaction bug remains *functional, not protocol* — `docs/spikes/protocol-checker-catches-bridge-bug.md`.
- **WS3.3 — Done.** `flake.nix` (uses `pkgs.sby`) + pinned `flake.lock`;
  `.github/workflows/formal.yml` runs `nix develop --command make all` (actionlint-clean).
  **CI is green** on GitHub Actions (`robtaylor/apb-formal`, run passes in ~44s).

**Exit:** golden Completer proves clean ✅; all covers reachable ✅; checker fails-as-intended on
injected non-compliance ✅; CI configured (pending first remote run).

## Phase exit criteria (project milestone 1)

- [x] Machine-readable spec + property catalog committed (WS1).
- [x] `fapb.sv` + golden Completer; `make prove` PASS, `make cover` all reachable (WS2, WS3.1).
- [x] Negative test: checker produces a counterexample on injected non-compliance (WS3.2).
      *(The specific libfpga bridge bug is functional, not protocol — see the spike.)*
- [x] CI green on a clean runner (WS3.3) — `robtaylor/apb-formal` GitHub Actions, passing.

## Next steps (milestone 2 candidates)

- ~~Parameter-selected checker role → real-RTL proof of libfpga `apb_splitter`~~ **done** (WS-A +
  WS3.2). Remaining real-RTL target: DOOMSoC regblocks.
- **Evaluate** a bridge transaction-accounting checker (`fahb`-style) that *would* catch the
  `ahbl_to_apb` double-transaction bug (next decision, per request).
- APB4 `PSTRB`/`PPROT` property branches (P15/P16) behind `F_OPT_*`.
- Golden Requester (`rtl/apb_requester_ref.sv`) + a Requester-checker proof.

## Notes

- Decisions are in `docs/adr/`; this plan schedules, it does not decide. Design detail for the
  protocol lives in `docs/spec/` and (later) `docs/apb-protocol-model.md`.
