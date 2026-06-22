// apb_completer_bad.sv — DELIBERATELY non-compliant Completer (negative test).
//
// Identical to apb_completer_ref EXCEPT PSLVERR is asserted throughout the ACCESS phase of an
// out-of-range access, not only in the completing cycle. This violates catalog property P13
// ("PSLVERR only on a completing access"). The fapb checker MUST catch it — a checker that
// can't fail on a known-bad design proves nothing (CLAUDE.md). Used by formal/negtest.sby
// with `expect fail`.

module apb_completer_bad #(
    parameter int unsigned ADDR_WIDTH = 12,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned NREG       = 16,
    parameter int unsigned NWAIT      = 1,
    parameter bit          F_OPT_SLVERR = 1
) (
    input                    PCLK,
    input                    PRESETn,
    input  [ADDR_WIDTH-1:0]  PADDR,
    input                    PWRITE,
    input                    PSEL,
    input                    PENABLE,
    input  [DATA_WIDTH-1:0]  PWDATA,
    output                   PREADY,
    output [DATA_WIDTH-1:0]  PRDATA,
    output                   PSLVERR
);
    localparam int unsigned IDXW = (NREG <= 1) ? 1 : $clog2(NREG);

    reg [DATA_WIDTH-1:0] mem [0:NREG-1];

    wire             access   = PSEL && PENABLE;
    wire [IDXW-1:0]  idx      = PADDR[IDXW+1:2];
    wire             in_range = (PADDR >> 2) < NREG;

    reg [7:0] wcnt;
    always @(posedge PCLK)
        if (!PRESETn)               wcnt <= 8'd0;
        else if (access && !PREADY) wcnt <= wcnt + 8'd1;
        else                        wcnt <= 8'd0;

    assign PREADY  = access && (wcnt == NWAIT[7:0]);
    assign PRDATA  = (access && !PWRITE && in_range) ? mem[idx] : {DATA_WIDTH{1'b0}};

    // *** BUG: not gated by PREADY -> PSLVERR asserts during wait cycles too (violates P13). ***
    assign PSLVERR = F_OPT_SLVERR && access && !in_range;

    always @(posedge PCLK)
        if (PRESETn && access && PREADY && PWRITE && in_range)
            mem[idx] <= PWDATA;

endmodule
