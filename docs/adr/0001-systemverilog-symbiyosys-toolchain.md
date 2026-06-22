# ADR 0001 — SystemVerilog + SymbiYosys as the formal toolchain

**Status:** Accepted (2026-06-22).

**TL;DR.** In the context of building a reusable APB protocol checker, facing a choice of
formal toolchains, we chose **SystemVerilog immediate assertions proven with open-source
SymbiYosys / Yosys** to achieve a fully FOSS, RTL-bindable checker reusable on any APB
design, accepting that we cannot use concurrent SVA (`property`/`sequence`/`bind`).

## Context

APB RTL in the wild is Verilog/SystemVerilog (iammituraj, Wren6991 libfpga & DOOMSoC, etc.).
The best open-source reference for a formal bus checker is ZipCPU's `wb2axip/bench/formal/
fapb_slave.v`, proven with SymbiYosys. The one prior "APB formal verification" project we
evaluated (Ghonimo AHB2APB) is built on **Synopsys VC Formal** (commercial) and its assertions
are implementation-specific FSM checks, not a reusable protocol library.

A checker is only useful if it can attach to arbitrary APB RTL and run on tooling we (and CI)
can install freely. The user's environment already has `yosys 0.64` and `sby v0.64`.

## Decision

1. Properties are written in **SystemVerilog** and proven with **SymbiYosys** over **Yosys**,
   using an SMT solver (boolector/yices).
2. Because open-source Yosys does **not** parse full concurrent SVA, checks are written as
   **immediate assertions inside a clocked `always` block**, using `$past`, `$rose`,
   `$stable`, `$fell`. This is the `fapb_slave.v` style.
3. The checker attaches to a DUT by **instantiation inside an SBY wrapper module**, not via
   the SystemVerilog `bind` construct.
4. The toolchain is provisioned via a pinned **`nix` flake** (reproducible, reused in CI),
   with `brew install yosys` documented as a lightweight local fallback.

## Alternatives considered

- **Amaranth (Python HDL) formal** — rejected as the *primary* target: APB is not in
  `amaranth-soc` today, and an Amaranth model would not bind directly to external SV/Verilog
  RTL, which is most of what we want to check. May be added later as a wrapper.
- **Abstract spec in TLA+ / a proof assistant** — rejected: proves the protocol abstractly
  but cannot check real hardware, which is the point here.
- **Commercial formal (VC Formal / JasperGold)** — rejected: not FOSS, not installable in
  open CI; the one APB precedent on VC Formal was not reusable anyway.

## Consequences

- Checker runs on free tooling; CI needs only the nix flake.
- Same property file binds to any APB RTL regardless of source language.
- **Cost:** no concurrent SVA — sequence-heavy properties must be hand-encoded as immediate
  assertions with explicit `$past`-based state. Slightly more verbose, but portable.
- k-induction may need depth tuning and a bounded-stall counter to converge.

## Walk-back options

- **If we need richer temporal properties** that immediate assertions express awkwardly —
  evaluate the SymbioticEDA/Tabby commercial Verific front-end for concurrent SVA, keeping
  the same property intent.
- **If the project pivots to a pure-Amaranth SoC** — add an Amaranth interface wrapper around
  the same property set rather than rewriting the proofs.

## Links

- `docs/plans/apb-formal-roadmap.md` — execution plan.
- ADR 0003 — the checker shape that depends on this toolchain.
- Reference: ZipCPU `wb2axip/bench/formal/fapb_slave.v` (SymbiYosys-proven APB slave checker).
