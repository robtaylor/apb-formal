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
