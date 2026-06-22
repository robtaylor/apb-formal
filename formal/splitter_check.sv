// splitter_check.sv — real-RTL proof harness for libfpga apb_splitter (WS-C).
//
// apb_splitter is multi-interface: one upstream Completer port (apbs_*) and N downstream
// Requester ports (apbm_*). We attach:
//   - 1x fapb (COMPLETER_CHECK) on apbs_*  -> assume a legal upstream Requester,
//     assert the splitter's upstream-completer obligations.
//   - Nx fapb (REQUESTER_CHECK) on each apbm_* -> assert the splitter's downstream-requester
//     legality, assume the (free) downstream Completer responses are legal.
// Net: every assert = a splitter obligation; every assume = a legal environment.
//
// The splitter is combinational (no clock); PCLK/PRESETn here only drive the checkers and give
// the temporal frame. Upstream F_OPT_SLVERR_STRICT=0: the splitter drives apbs_pslverr/decode
// combinationally from PADDR (HIGH on a decode miss even when idle) — a spec *recommendation*
// deviation (§3.4), not a hard violation, so we do not assert the gating rule on it. See
// docs/spikes/apb-splitter-pslverr-ungated.md.

`include "apb_if.svh"

module splitter_check #(
    parameter integer W_ADDR   = 16,
    parameter integer W_DATA   = 32,
    parameter integer N_SLAVES = 2
) (
    input                          PCLK,
    input                          PRESETn,
    // upstream Requester signals (free inputs, constrained legal by the upstream checker)
    input  [W_ADDR-1:0]            apbs_paddr,
    input                          apbs_psel,
    input                          apbs_penable,
    input                          apbs_pwrite,
    input  [W_DATA-1:0]            apbs_pwdata,
    // downstream Completer responses (free inputs, assumed legal by the downstream checkers)
    input  [N_SLAVES-1:0]          apbm_pready,
    input  [N_SLAVES*W_DATA-1:0]   apbm_prdata,
    input  [N_SLAVES-1:0]          apbm_pslverr
);
    wire                        apbs_pready;
    wire [W_DATA-1:0]           apbs_prdata;
    wire                        apbs_pslverr;
    wire [N_SLAVES*W_ADDR-1:0]  apbm_paddr;
    wire [N_SLAVES-1:0]         apbm_psel;
    wire [N_SLAVES-1:0]         apbm_penable;
    wire [N_SLAVES-1:0]         apbm_pwrite;
    wire [N_SLAVES*W_DATA-1:0]  apbm_pwdata;

    apb_splitter #(
        .W_ADDR(W_ADDR), .W_DATA(W_DATA), .N_SLAVES(N_SLAVES),
        .ADDR_MAP(32'h0000_4000), .ADDR_MASK(32'hc000_c000)
    ) dut (
        .apbs_paddr(apbs_paddr), .apbs_psel(apbs_psel), .apbs_penable(apbs_penable),
        .apbs_pwrite(apbs_pwrite), .apbs_pwdata(apbs_pwdata),
        .apbs_pready(apbs_pready), .apbs_prdata(apbs_prdata), .apbs_pslverr(apbs_pslverr),
        .apbm_paddr(apbm_paddr), .apbm_psel(apbm_psel), .apbm_penable(apbm_penable),
        .apbm_pwrite(apbm_pwrite), .apbm_pwdata(apbm_pwdata),
        .apbm_pready(apbm_pready), .apbm_prdata(apbm_prdata), .apbm_pslverr(apbm_pslverr)
    );

    // Upstream: Completer-checker. F_OPT_SLVERR_STRICT=0 — the splitter drives apbs_pslverr
    // combinationally from PADDR, ungated by PSEL (legal per §3.4, just not recommended; see
    // docs/spikes/apb-splitter-pslverr-ungated.md). F_OPT_LIVENESS=0 — do not assert a bounded
    // upstream stall; liveness is inherited from the downstream Completers, which the spec does
    // not bound, so we neither assume nor assert it here (audit finding, ADR 0001).
    fapb #(
        .ADDR_WIDTH(W_ADDR), .DATA_WIDTH(W_DATA),
        .F_OPT_ROLE(`FAPB_COMPLETER_CHECK),
        .F_OPT_SLVERR(1), .F_OPT_SLVERR_STRICT(0), .F_OPT_LIVENESS(0), .F_OPT_MAXSTALL(8)
    ) chk_up (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .PADDR(apbs_paddr), .PWRITE(apbs_pwrite), .PSEL(apbs_psel),
        .PENABLE(apbs_penable), .PWDATA(apbs_pwdata),
        .PREADY(apbs_pready), .PRDATA(apbs_prdata), .PSLVERR(apbs_pslverr)
    );

    // Downstream: one Requester-checker per slave port.
    genvar g;
    generate
        for (g = 0; g < N_SLAVES; g = g + 1) begin : dn
            // F_OPT_LIVENESS=0 — do not *assume* a bounded downstream stall (the spec permits
            // unbounded waits); proving the splitter for all stall lengths is stronger.
            fapb #(
                .ADDR_WIDTH(W_ADDR), .DATA_WIDTH(W_DATA),
                .F_OPT_ROLE(`FAPB_REQUESTER_CHECK),
                .F_OPT_SLVERR(1), .F_OPT_SLVERR_STRICT(1), .F_OPT_LIVENESS(0), .F_OPT_MAXSTALL(8)
            ) chk_dn (
                .PCLK(PCLK), .PRESETn(PRESETn),
                .PADDR(apbm_paddr[g*W_ADDR +: W_ADDR]),
                .PWRITE(apbm_pwrite[g]), .PSEL(apbm_psel[g]), .PENABLE(apbm_penable[g]),
                .PWDATA(apbm_pwdata[g*W_DATA +: W_DATA]),
                .PREADY(apbm_pready[g]), .PRDATA(apbm_prdata[g*W_DATA +: W_DATA]),
                .PSLVERR(apbm_pslverr[g])
            );
        end
    endgenerate

endmodule
