// apb_completer_ref.sv — minimal compliant APB-lite Completer (golden reference).
//
// Purpose: self-test the fapb checker (ADR 0003). A small word-addressed register file with
// configurable wait states and an out-of-range error response. Designed to satisfy every
// Completer-side property in docs/spec/property-catalog.md (P11-P14, L1).
//
//   NWAIT = 0 -> zero-wait (PREADY high in the ACCESS cycle).
//   NWAIT > 0 -> inserts NWAIT wait cycles before completing.

module apb_completer_ref #(
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
    wire [IDXW-1:0]  idx      = PADDR[IDXW+1:2];                 // word index
    wire             in_range = (PADDR >> 2) < NREG;

    // Wait-state counter: ready once NWAIT access cycles have elapsed.
    reg [7:0] wcnt;
    always @(posedge PCLK)
        if (!PRESETn)               wcnt <= 8'd0;
        else if (access && !PREADY) wcnt <= wcnt + 8'd1;
        else                        wcnt <= 8'd0;

    assign PREADY  = access && (wcnt == NWAIT[7:0]);

    // Combinational read data: valid (never X) in the completing read cycle.
    assign PRDATA  = (access && !PWRITE && in_range) ? mem[idx] : {DATA_WIDTH{1'b0}};

    // Error only on a completing access (satisfies P13); out-of-range address.
    assign PSLVERR = F_OPT_SLVERR && access && PREADY && !in_range;

    // Write commits on the completing cycle.
    always @(posedge PCLK)
        if (PRESETn && access && PREADY && PWRITE && in_range)
            mem[idx] <= PWDATA;

endmodule
