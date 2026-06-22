// completer_check.sv — SBY proof wrapper: golden Completer + fapb checker (Completer mode).
//
// Top-level inputs are the Requester-driven APB signals; the solver drives them freely and
// fapb's `assume`s (default = Completer-checker) constrain them to legal stimulus. The DUT
// drives PREADY/PRDATA/PSLVERR, which fapb `assert`s against the protocol.

module completer_check #(
    parameter int unsigned ADDR_WIDTH = 12,
    parameter int unsigned DATA_WIDTH = 32
) (
    input                   PCLK,
    input                   PRESETn,
    input  [ADDR_WIDTH-1:0] PADDR,
    input                   PWRITE,
    input                   PSEL,
    input                   PENABLE,
    input  [DATA_WIDTH-1:0] PWDATA
);
    wire                  PREADY;
    wire [DATA_WIDTH-1:0] PRDATA;
    wire                  PSLVERR;

    apb_completer_ref #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .NREG(16), .NWAIT(1), .F_OPT_SLVERR(1)
    ) dut (.*);

    fapb #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .F_OPT_SLVERR(1), .F_OPT_MAXSTALL(8)
    ) chk (.*);

endmodule
