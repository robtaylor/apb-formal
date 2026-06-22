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
| `rtl/` | Parameterized APB interface + golden reference Completer/Requester |
| `formal/` | The `fapb` checker and SymbiYosys proof configs |

## Toolchain

Yosys + SymbiYosys + an SMT solver. Provision via `nix develop` (pinned `flake.nix`) or
`brew install yosys` for a quick local setup. See [ADR 0001](docs/adr/0001-systemverilog-symbiyosys-toolchain.md).

```sh
make prove   # k-induction proofs of the golden Completer
make cover    # reachability of every protocol scenario
make all
```

## Status

Early development. See [`docs/plans/apb-formal-roadmap.md`](docs/plans/apb-formal-roadmap.md).
