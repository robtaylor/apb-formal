# ADR 0002 — Scope: "APB-lite" = the 10-signal core + APB3

**Status:** Accepted (2026-06-22).

**TL;DR.** In the context of defining what the checker must cover, facing the spread of APB
revisions (APB2–APB5) in IHI0024E, we chose to model the **10-signal core plus APB3 `PREADY`
and `PSLVERR`** as mandatory and parameterize APB4/APB5 features **off**, to achieve a faithful
model of what real implementations actually use, accepting that protection/strobe/parity/RME
features are deferred.

## Context

"APB-lite" is not a term defined in IHI0024E. Surveying five independent open-source sources
(iammituraj/apb, Wren6991 libfpga `ahbl_to_apb`/`apb_splitter`, Wren6991 DOOMSoC regblocks, and
a local libfpga AHBL→APB bridge-bug reproducer) showed unanimous convergence: every one
implements the same core signal set; **none** implement `PPROT`, `PWAKEUP`, or any APB5
feature, and only one declares `PSTRB` (unused). The spec itself layers these as later
additions (PREADY/PSLVERR in APB3, PPROT/PSTRB in APB4, wakeup/user/parity/RME in APB5).

## Decision

1. **Mandatory (the APB-lite contract):**
   `PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA`
   plus `PREADY` (wait states) and `PSLVERR` (error response). This is the in-scope set the
   checker proves and the golden Completer implements.
2. **Parameterized, default off (designed-in, not built):** `PSTRB`, `PPROT` (APB4) behind
   `F_OPT_PSTRB` / `F_OPT_PPROT`; `PSLVERR` itself gated by `F_OPT_SLVERR` so the
   fixed-2-cycle, no-error "APB2-style" slave is a constrained instance.
3. **Out of scope (this project):** `PWAKEUP`, user signals (`PAUSER/PWUSER/PRUSER/PBUSER`),
   interface parity (Chapter 5 / `*CHK`), and RME/`PNSE`.

## Alternatives considered

- **Through APB4 (add PPROT + PSTRB now)** — rejected for the initial model: real OSS usage is
  ~0; better to land the core proven, then add PSTRB stability/`PSTRB==0`-on-read rules behind
  the parameter when a consumer needs them.
- **Full APB5 (entire IHI0024E incl. parity + RME)** — rejected: large surface area, essentially
  untested in any open RTL, would delay a working core checker substantially.

## Consequences

- The model matches what implementers actually build, so validation against real RTL is
  meaningful immediately.
- `PSTRB`/`PPROT` hooks exist (parameters), so extending later is additive, not a rewrite.
- **Cost:** a design using PPROT/PSTRB/APB5 is only *partially* checked until those parameters
  and their properties are implemented.

## Walk-back options

- **If a consumer needs APB4** — implement the `F_OPT_PSTRB`/`F_OPT_PPROT` property branches
  (catalog rows 18–20 already enumerate them) and flip the defaults per-instance.
- **If APB5 parity becomes relevant** — a new ADR + a Chapter-5 property module; do not bolt it
  onto the core file.

## Links

- `docs/spec/property-catalog.md` — per-row in-scope/out-of-scope tags follow this decision.
- ADR 0003 — checker structure that carries these parameters.
