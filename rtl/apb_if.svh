// apb_if.svh — shared definitions for the APB-lite formal model.
//
// We deliberately do NOT use a SystemVerilog `interface` construct: the open-source Yosys
// formal flow (ADR 0001) is happiest with a flat port list, and `bind`/virtual-interface
// machinery is unavailable. Instead this header carries (a) the Requester/Completer
// assume/assert role-selection macros, and (b) the role constants.
//
// Signal ownership (APB-lite + APB3, ADR 0002):
//   Requester-driven (R): PADDR, PWRITE, PSEL, PENABLE, PWDATA
//   Completer-driven (C): PREADY, PRDATA, PSLVERR
//   Shared:               PCLK, PRESETn

`ifndef APB_IF_SVH
`define APB_IF_SVH

// Checker role (ADR 0003, mechanism amended 2026-06-22 — see ADR 0003 §Amendment). Selected by
// the `F_OPT_ROLE` *parameter* of the `fapb` module (an elaboration-time constant), NOT a
// compile define. This lets multiple `fapb` instances with different roles coexist in one
// elaboration — required to check a multi-interface DUT such as apb_splitter (one upstream
// Completer port + N downstream Requester ports).
`define FAPB_COMPLETER_CHECK 0   // assume a legal Requester, assert the Completer's obligations
`define FAPB_REQUESTER_CHECK 1   // flip: assert the Requester, assume a legal Completer

// Property macros. `APB_REQ` guards a Requester-driven property; `APB_CMP` a Completer-driven
// one. Each expands to a complete if/else with begin/end so it is safe to invoke inside other
// conditionals (no dangling-else / trailing-semicolon hazard). They reference the enclosing
// module's `F_OPT_ROLE` parameter by name (always in scope inside `fapb`).
`define APB_REQ(p) if (F_OPT_ROLE == `FAPB_REQUESTER_CHECK) begin assert (p); end else begin assume (p); end
`define APB_CMP(p) if (F_OPT_ROLE == `FAPB_REQUESTER_CHECK) begin assume (p); end else begin assert (p); end

`endif // APB_IF_SVH
