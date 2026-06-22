# ADR 0004 — WaveDrom as the machine-readable waveform format

**Status:** Accepted (2026-06-22).

**TL;DR.** In the context of capturing the spec's timing diagrams, facing the need for a
diffable, reviewable, renderable representation, we chose **WaveDrom JSON5 rendered to SVG**
to achieve version-controllable waveforms that a human and a checker author can both read,
accepting a small `npx wavedrom-cli` build dependency.

## Context

IHI0024E defines APB timing as six figures (write/read × no-wait/wait/error). These are the
ground truth the checker's stability and handshake properties must match. A PDF bitmap is not
reviewable or diffable. The waveforms need to live in the repo in a form that (a) renders to a
picture for humans, (b) is plain text for `git diff` and review, and (c) can be annotated with
the spec's T-cycle phase labels.

## Decision

1. Each in-scope timing diagram is transcribed to a **WaveDrom JSON5** source under
   `docs/spec/waveforms/*.json5` and rendered to **SVG** via `npx wavedrom-cli`.
2. The `IDLE→SETUP→ACCESS` state machine (Fig 4-1) is captured as a **Graphviz `.dot`** file
   (state diagrams are not WaveDrom's domain) plus a state/transition table in markdown.
3. Source `.json5` is the source of truth; rendered `.svg` is committed for convenience and
   embedded in `docs/spec/IHI0024E.md`.

## Alternatives considered

- **Raw SVG hand-drawn** — rejected: not diffable, easy to get subtly wrong.
- **ASCII timing diagrams** — rejected: don't render cleanly, hard to align many signals.
- **Commit the PDF page crops only** — rejected: bitmaps aren't reviewable and the PDF isn't
  committed for licensing reasons.

## Consequences

- Waveforms are reviewable in PRs and can be corrected with a one-line edit.
- The same `.json5` doubles as documentation of exactly which cycle each phase occupies, which
  the property author reads when encoding `$past`-based timing.
- **Cost:** rendering needs Node/`npx` (no global install); CI or docs build must run it to
  refresh SVGs.

## Walk-back options

- **If WaveDrom proves limiting** — the JSON5 is simple enough to regenerate into another format;
  the phase annotations (the load-bearing part) are plain data.

## Links

- `docs/spec/waveforms/` — the sources and renders.
- `docs/spec/IHI0024E.md` — embeds the renders.
