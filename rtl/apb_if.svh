// apb_if.svh — shared definitions for the APB-lite formal model.
//
// We deliberately do NOT use a SystemVerilog `interface` construct: the open-source Yosys
// formal flow (ADR 0001) is happiest with a flat port list, and `bind`/virtual-interface
// machinery is unavailable. Instead this header carries (a) the Requester/Completer
// assume/assert role-flip macros, and (b) default width parameters. Modules take an explicit
// flat APB-lite port list (see fapb.sv / apb_completer_ref.sv).
//
// Signal ownership (APB-lite + APB3, ADR 0002):
//   Requester-driven (R): PADDR, PWRITE, PSEL, PENABLE, PWDATA
//   Completer-driven (C): PREADY, PRDATA, PSLVERR
//   Shared:               PCLK, PRESETn

`ifndef APB_IF_SVH
`define APB_IF_SVH

// Role-flip (ADR 0003). Default = Completer-checker: assume a legal Requester, assert the
// Completer's obligations. Define FAPB_REQUESTER to flip and check a Requester instead.
`ifdef FAPB_REQUESTER
  `define APB_REQ assert   // Requester signals are the DUT's obligations
  `define APB_CMP assume   // Completer signals are assumed legal
`else
  `define APB_REQ assume   // Requester signals are assumed-legal stimulus
  `define APB_CMP assert   // Completer signals are the DUT's obligations
`endif

`endif // APB_IF_SVH
