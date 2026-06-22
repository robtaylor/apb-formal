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
