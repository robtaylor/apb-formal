// negtest_check.sv — wrapper binding the fapb checker to the deliberately-broken Completer.
// Expected result: FAIL (catalog P13 violated). See formal/negtest.sby (`expect fail`).

module negtest_check #(
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

    apb_completer_bad #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .NREG(16), .NWAIT(1), .F_OPT_SLVERR(1)
    ) dut (.*);

    fapb #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .F_OPT_SLVERR(1), .F_OPT_MAXSTALL(8)
    ) chk (.*);

endmodule
