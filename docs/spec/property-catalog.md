# APB-lite property catalog

The bridge from spec → checker. Every assertion in `formal/fapb.sv` must trace to a row here;
every in-scope row here must become an assertion. Rows are de-duplicated from the spec
(IHI0024E, captured in [`IHI0024E.md`](IHI0024E.md)), cross-checked against open-source VIPs
and ZipCPU's `fapb_slave.v`.

## Legend

- **Drives** — who drives the signals the rule constrains: **R** = Requester, **C** = Completer.
  In a **Completer-checker**, R-rows are `assume` (legal stimulus) and C-rows are `assert`
  (the DUT's obligations). In a **Requester-checker**, the macro flip reverses this. (ADR 0003.)
- **Scope** — ✅ in scope (APB-lite + APB3) · ⬜ out of scope (APB4/APB5, parameterized off, ADR 0002).
- **Cite** — section/figure of IHI0024E.

Notation in encodings: `p` = `$past`, `$rose/$fell/$stable` as in SVA; all sampled at
`posedge PCLK`, `disable iff (!PRESETn)`. `sel=PSEL`, `en=PENABLE`, `rdy=PREADY`.

## Safety properties

| # | Property | Cite | Scope | Drives | Encoding sketch |
|---|----------|------|-------|--------|-----------------|
| P1 | **Reset → idle.** While/just after reset, `!PSEL && !PENABLE`. | §4, App B defaults | ✅ | R | `!PRESETn \|⇒ !sel && !en` (and initial). |
| P2 | **Setup has enable low.** The first selected cycle of a transfer has `PENABLE` low. | §3.1, §4 | ✅ | R | `$rose(sel) \|-> !en`  (more precisely: `sel && !p(sel) \|-> !en`). |
| P3 | **Setup lasts one cycle → access.** A setup cycle (`sel && !en`) is always followed by an access cycle (`sel && en`). | §4 | ✅ | R | `sel && !en \|⇒ sel && en`. |
| P4 | **No enable without select.** `PENABLE \|-> PSEL`. | §4 (ACCESS has PSEL=1) | ✅ | R | `en \|-> sel`.  *(VIP gap — neither surveyed VIP asserts this.)* |
| P5 | **Access holds until ready.** In access with `PREADY` low, stay in access next cycle. | §3.1.2, §3.3.2, §4 | ✅ | R | `sel && en && !rdy \|⇒ sel && en`. |
| P6 | **Enable deasserts on completion.** A completing access (`sel && en && rdy`) is followed by `!PENABLE`. | §3.1, §4 | ✅ | R | `sel && en && rdy \|⇒ !en`.  (≡ `en == !p(rdy)` while selected.) |
| P7 | **PADDR stable through transfer.** `PADDR` is held from setup until the transfer completes. | §3.1.2, §3.3.2, §4 | ✅ | R | `p(sel) && !(p(en)&&p(rdy)) \|-> $stable(PADDR)`. |
| P8 | **PWRITE stable through transfer.** As P7 for `PWRITE`. | §3.1.2, §3.3.2, §4 | ✅ | R | `p(sel) && !(p(en)&&p(rdy)) \|-> $stable(PWRITE)`. |
| P9 | **PWDATA stable through write transfer.** As P7 for `PWDATA` when `PWRITE`. | §3.1.2, §4 | ✅ | R | `p(sel)&&p(PWRITE) && !(p(en)&&p(rdy)) \|-> $stable(PWDATA)`. |
| P10 | **PADDR valid (not X) when selected.** | App A | ✅ | R | `sel \|-> !$isunknown(PADDR)`. |
| P11 | **PREADY valid when selected & enabled.** | App A | ✅ | C | `sel && en \|-> !$isunknown(rdy)`. |
| P12 | **PRDATA valid on completing read.** | App A | ✅ | C | `sel && en && rdy && !PWRITE \|-> !$isunknown(PRDATA)`. |
| P13 | **PSLVERR confined to an ACCESS phase.** `PSLVERR` HIGH only when `PSEL && PENABLE`. | §3.4 (recommendation) | ✅ | C | `!PSLVERR \|\| (sel&&en)`. Tier 1 of the §3.4 recommendation; gated by `F_OPT_SLVERR_STRICT`. |
| P14 | **PSLVERR further confined to the completing cycle.** Additionally requires `PREADY`. | §3.4 (recommendation) | ✅ | C | `!PSLVERR \|\| rdy`. Tier 2; gated by `F_OPT_SLVERR_STRICT`. P13&&P14 ≡ `PSLVERR \|-> completing`. |
| P15 | **PSTRB low on reads.** | §3.2 | ⬜ | R | `sel && !PWRITE \|-> PSTRB == 0`. Behind `F_OPT_PSTRB`. |
| P16 | **PSTRB/PPROT/PWDATA-lanes stable through access.** | §4 | ⬜ | R | `$stable(PSTRB)`, `$stable(PPROT)` in the P7 window. Behind `F_OPT_PSTRB`/`F_OPT_PPROT`. |

> **PSLVERR is a recommendation, not a hard rule (`F_OPT_SLVERR_STRICT`).** §3.4's "only
> *considered valid* in the last cycle" governs the *consumer*; the only obligation on the
> *Completer's driver* is the recommendation that `PSLVERR` be LOW unless the transfer is
> completing ("recommended, but not required"). So there is **no** hard PSLVERR assert to
> separate out — P13 and P14 are two diagnosable **tiers of that one recommendation** (confined
> to an access phase, then to the completing cycle), and `P13 && P14 ≡ PSLVERR ⇒ completing`.
> Both are gated by `F_OPT_SLVERR_STRICT` (default `1`; used for the golden Completer and the
> negative test). Set `0` for RTL that drives `PSLVERR` ungated by `PSEL` — legal per §3.4, just
> not recommended (e.g. libfpga `apb_splitter`; see `docs/spikes/apb-splitter-pslverr-ungated.md`).

> **L1 bounded stall is design-specific, gated by `F_OPT_LIVENESS`.** §3.3.2 permits *any* number
> of wait cycles, so the bounded-stall counter is not a spec rule — it is a safety encoding of
> "every transfer eventually completes". Default `1` (asserted for the golden Completer). Set `0`
> where the spec's unbounded-wait semantics must be honoured — notably as an *assumption* on an
> environment Completer in a requester/splitter proof, where bounding it would silently weaken
> the proof (audit finding).

> **P10–P12 (the App-A "signal not X" rules)** are *not asserted* in the formal build: Yosys's
> SMT backend is 2-state, so `$isunknown` is vacuously false and the checks carry no proof
> content. They remain valid as simulation-time assertions and are documented here for
> completeness; see the header of `formal/fapb.sv`.

## Liveness / forward-progress

| # | Property | Cite | Scope | Drives | Encoding sketch |
|---|----------|------|-------|--------|-----------------|
| L1 | **Bounded stall (liveness proxy).** Once in access, `PREADY` goes HIGH within `F_OPT_MAXSTALL` cycles. | §3 (transfers complete); **no hard bound in spec** | ✅ | C | counter on `sel && en && !rdy`; `assert(count < F_OPT_MAXSTALL)`, gated by `F_OPT_LIVENESS`. A *safety encoding* of "every transfer eventually completes" — see ADR 0001 and the `F_OPT_LIVENESS` note above. |
| L2 | **Two-cycle minimum.** Every transfer occupies ≥2 cycles (setup + access). | §1 | ✅ | — | Emergent from P2+P3; assert via cover, not a standalone obligation. |

## Cover scenarios (reachability — prove the checker isn't vacuous)

| # | Scenario | Cite |
|---|----------|------|
| C1 | Completed write, no wait states | Fig 3-1 |
| C2 | Completed read, no wait states | Fig 3-4 |
| C3 | Transfer with ≥1 wait state | Fig 3-2 / 3-5 |
| C4 | Transfer completing with `PSLVERR` | Fig 3-6 / 3-7 |
| C5 | Back-to-back transfers (no IDLE between: access → setup) | §3.1, §4 |
| C6 | Transfer then return to IDLE | §4 |

## Notes on rules that are *stronger than the spec* (do not adopt as universal)

Surveyed VIPs encode two invariants the AMBA spec does **not** require — keep them only as
optional, design-specific checks, never as core protocol asserts:

- "All control/data are zero in IDLE (`!PSEL`)." The spec only requires `PSEL` deasserted and
  *recommends* (App A) driving unused signals to zero — it does not mandate it.
- "All signals `$fell` the cycle after completion." The spec requires `PENABLE` deassert
  (P6) and `PSEL` deassert unless another transfer follows — not a synchronized fall of every
  signal.
