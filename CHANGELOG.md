# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project predates its first release.

## [Unreleased]

### Added
- Project scaffolding: four-document discipline (`docs/adr`, `docs/plans`, `docs/spikes`,
  `docs/handoffs`), `CLAUDE.md`, `README.md`.
- ADRs 0001–0004 recording the toolchain, scope, deliverable, and waveform-format decisions.
- Roadmap plan at `docs/plans/apb-formal-roadmap.md`.
- Machine-readable spec capture `docs/spec/IHI0024E.md` (signals, transfers, state machine,
  validity rules, signal matrix, revisions, dependency finding).
- WaveDrom sources + rendered SVGs for the six APB timing diagrams (Fig 3-1/3-2/3-4/3-5/3-6/3-7)
  and a Graphviz state machine (Fig 4-1) under `docs/spec/waveforms/`.
- Property catalog `docs/spec/property-catalog.md` mapping each protocol rule to a spec
  citation and an assertion side.
- `formal/fapb.sv`: the APB-lite + APB3 compliance checker (immediate assertions, macro-flip
  Requester/Completer role) implementing catalog properties P1–P9, P13/P14, L1 and covers C1–C6.
- `rtl/apb_if.svh`: shared role-flip macros. `rtl/apb_completer_ref.sv`: golden reference
  Completer (register file, configurable wait states, out-of-range error).
- `formal/completer.sby` + `formal/completer_check.sv` + `Makefile`: proof harness.
  **`make prove` passes by k-induction; `make cover` reaches all six scenarios.**
- Negative test: `rtl/apb_completer_bad.sv` + `formal/negtest.sby` (`expect fail`) +
  `make negtest` — proves the checker catches an injected P13 violation.
- `flake.nix` + `flake.lock` (pinned nixpkgs) and `.github/workflows/formal.yml` running
  `nix develop --command make all`.
- Spike `docs/spikes/protocol-checker-catches-bridge-bug.md`: the libfpga `ahbl_to_apb`
  double-transaction bug is functional, not a protocol violation — the protocol checker is
  necessary but not sufficient; catching it needs a bridge transaction-accounting property.

### Changed
- `fapb` checker role is now a **parameter** (`F_OPT_ROLE`) instead of a compile define, so
  multiple instances with different roles coexist (ADR 0003 amended). Added `F_OPT_SLVERR_STRICT`
  to gate the §3.4 PSLVERR recommendation.
- **Audit follow-ups** (from the formal-model vs spec audit):
  - Added `F_OPT_LIVENESS` (default 1) to gate the bounded-stall proxy L1, which is a
    design-specific bound, not a spec rule. The `apb_splitter` checkers now set it `0`, so the
    splitter is proven for *any* downstream stall length (previously it silently assumed ≤8).
  - Split the PSLVERR recommendation into two diagnosable tiers (P13 "confined to access", P14
    "confined to the completing cycle"), both gated by `F_OPT_SLVERR_STRICT`; corrected the
    catalog wording (it is a §3.4 *recommendation*, not a hard rule).
  - Broadened the negative test: `make negtest` now runs two `expect fail` tasks — `pslverr`
    (P13/P14) and `stall` (L1) — so the checker is shown to catch structurally different bugs.
  - Tagged every property in `fapb.sv` with `[cat <id> | <spec §>]` and added user
    documentation (usage, parameter table, what-it-proves, limitations) to `README.md`.

### Added (real-RTL validation)
- Vendored libfpga `apb_splitter.v` + `onehot_mux.v` (WTFPL) under `third_party/libfpga/`.
- `formal/splitter_check.sv` + `formal/splitter.sby`: multi-interface harness (1 upstream
  Completer-checker + N downstream Requester-checkers). **`make splitter` proves `apb_splitter`
  compliant by k-induction; covers reachable.** Now part of `make all`.
- Spike `docs/spikes/apb-splitter-pslverr-ungated.md`: the checker found (and a verified
  strict-mode counterexample confirms) that `apb_splitter` drives `PSLVERR` ungated by `PSEL` —
  a spec recommendation-level deviation, not a bug.
