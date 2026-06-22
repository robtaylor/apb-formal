# apb-formal

A reusable, open-source **formal protocol-compliance checker** for the ARM AMBA **APB**
bus and its "APB-lite" subset, proven with [SymbiYosys](https://github.com/YosysHQ/sby) /
[Yosys](https://github.com/YosysHQ/yosys).

The checker is an `assume`/`assert` property suite that can be attached to any APB
**Requester** or **Completer** to prove it complies with the protocol defined in
[Arm IHI 0024E](https://developer.arm.com/documentation/ihi0024/e/). It is grounded in a
machine-readable capture of the specification (`docs/spec/`) and validated against real
open-source APB RTL.

## Scope

"**APB-lite**" here means the 10-signal core that every real implementation converges on,
plus the APB3 handshake/error signals:

```
PCLK PRESETn PSEL PENABLE PWRITE PADDR PWDATA PRDATA   (core)
PREADY    — wait states (APB3)
PSLVERR   — error response (APB3)
```

APB4 (`PPROT`, `PSTRB`) and APB5 (`PWAKEUP`, user signals, parity, RME/`PNSE`) are
designed-in as parameters but default **off** — see [ADR 0002](docs/adr/0002-apb-lite-scope.md).

## Layout

| Path | What |
|------|------|
| `docs/spec/` | Machine-readable IHI0024E (markdown, WaveDrom waveforms, property catalog) |
| `docs/adr/` | Why decisions were made |
| `docs/plans/` | What's next, in what order |
| `rtl/` | Shared header (`apb_if.svh`) + golden reference Completer (+ a deliberately-broken one for the negative test) |
| `formal/` | The `fapb` checker, proof wrappers, and SymbiYosys `.sby` configs |
| `third_party/libfpga/` | Vendored libfpga RTL (WTFPL) used as a real-RTL device-under-test |

## Toolchain

Yosys + SymbiYosys + an SMT solver. Provision via `nix develop` (pinned `flake.nix`) or
`brew install yosys` for a quick local setup. See [ADR 0001](docs/adr/0001-systemverilog-symbiyosys-toolchain.md).

```sh
make prove           # k-induction proof of the golden Completer
make cover           # reachability of every protocol scenario (C1-C6)
make negtest         # negative tests: the checker must catch injected bugs (sby `expect fail`)
make splitter        # real-RTL: prove libfpga apb_splitter compliant
make splitter-cover  # real-RTL scenario reachability
make bridge          # bridge accounting: catch the libfpga ahbl_to_apb double-transaction bug + prove the fix
make all             # all of the above
```

## Using the checker on your own design

`fapb` (in `formal/fapb.sv`) is the checker. You attach it to a device-under-test by
**instantiation in a small SBY wrapper** (not SystemVerilog `bind` — the open-source Yosys flow
doesn't support it). Pick the role with the `F_OPT_ROLE` parameter:

- checking a **Completer** (peripheral)? → `FAPB_COMPLETER_CHECK` (the default): the checker
  *assumes* a legal Requester drives the bus and *asserts* your Completer's `PREADY`/`PRDATA`/
  `PSLVERR` obey the protocol.
- checking a **Requester** (bridge/master)? → `FAPB_REQUESTER_CHECK`: the roles flip.

Minimal Completer-checker wrapper (see `formal/completer_check.sv` for the real one):

```systemverilog
`include "apb_if.svh"
module my_check (input PCLK, PRESETn,
                 input [11:0] PADDR, input PWRITE, PSEL, PENABLE, input [31:0] PWDATA);
    wire PREADY; wire [31:0] PRDATA; wire PSLVERR;     // driven by the DUT
    my_completer dut (.*);                              // your RTL
    fapb #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) chk (.*);  // default role = Completer-check
endmodule
```

The top-level inputs (the Requester-driven signals) are free — the solver explores all legal
stimulus, constrained by the checker's `assume`s. Then point an `.sby` file at it (copy
`formal/completer.sby`) and run `sby -f formal/my.sby prove`. For a multi-interface DUT (e.g. a
1-to-N splitter or a bridge), instantiate **several** `fapb` with different `F_OPT_ROLE` values —
see `formal/splitter_check.sv`.

### Parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `ADDR_WIDTH`, `DATA_WIDTH` | 12, 32 | `PADDR` / `PWDATA`/`PRDATA` widths. |
| `F_OPT_ROLE` | `FAPB_COMPLETER_CHECK` | Checker role; flip to `FAPB_REQUESTER_CHECK`. |
| `F_OPT_SLVERR` | 1 | DUT may drive `PSLVERR` (else it must be tied LOW). |
| `F_OPT_SLVERR_STRICT` | 1 | Enforce the §3.4 *recommendation* that `PSLVERR` is LOW unless the transfer is completing. Set **0** for RTL that drives `PSLVERR` ungated by `PSEL` (legal, just not recommended — e.g. `apb_splitter`). |
| `F_OPT_LIVENESS` | 1 | Assert the bounded-stall liveness proxy (`PREADY` within `F_OPT_MAXSTALL`). This is a *design-specific* bound, **not** an APB rule; set **0** for an environment Completer in a Requester/splitter proof (the spec permits unbounded waits). |
| `F_OPT_MAXSTALL` | 8 | The bound used by `F_OPT_LIVENESS`. |

### What it proves

Every assertion maps to a row of [`docs/spec/property-catalog.md`](docs/spec/property-catalog.md)
and a clause of IHI0024E (the `fapb.sv` source tags each one `[cat <id> | <spec §>]`): the
SETUP→ACCESS state machine, one-cycle SETUP, `PENABLE` timing, signal stability through a
transfer (incl. wait states), `PSEL`/`PENABLE` held during waits, the `PSLVERR` validity
recommendation, and bounded-stall liveness. Six `cover` scenarios (write/read × no-wait/wait/
error, back-to-back, return-to-idle) confirm the checker is not vacuous.

### Limitations

- Scope is APB-lite + APB3 ([ADR 0002](docs/adr/0002-apb-lite-scope.md)); APB4 `PPROT`/`PSTRB`
  and APB5 features are out of scope.
- The Yosys SMT backend is 2-state, so the App-A "signal not X" rules are not asserted (they have
  no proof content under 2-state semantics) — see [ADR 0001](docs/adr/0001-systemverilog-symbiyosys-toolchain.md).
- `fapb` is a *protocol* checker: it proves an interface speaks legal APB, not functional
  correctness across a bridge (e.g. transaction counts) — see
  [`docs/spikes/protocol-checker-catches-bridge-bug.md`](docs/spikes/protocol-checker-catches-bridge-bug.md).
  For *that* class of bug there is a separate **transaction-accounting** proof (`make bridge`,
  [ADR 0005](docs/adr/0005-ahbl-bridge-accounting.md)) that catches the real libfpga `ahbl_to_apb`
  double-transaction bug and proves the fix; it brings a minimal AHB-Lite master *model* into scope.

## Status

Early development; the checker is proven (k-induction) on a golden Completer and on libfpga's
`apb_splitter`, with CI green. See [`docs/plans/apb-formal-roadmap.md`](docs/plans/apb-formal-roadmap.md).
