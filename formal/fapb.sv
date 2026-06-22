// fapb.sv — APB-lite + APB3 protocol-compliance checker (ADR 0001/0002/0003).
//
// A property module to attach (by instantiation in an SBY wrapper — NOT `bind`) to an APB
// Requester or Completer. Every property traces to a row in docs/spec/property-catalog.md.
//
//   Default build (no define)  : Completer-checker — `APB_REQ = assume`, `APB_CMP = assert`.
//   +define+FAPB_REQUESTER      : Requester-checker — roles flipped.
//
// Style: immediate assertions in a clocked block using $past/$stable; 2-state SMT semantics
// (no $isunknown X-checks — vacuous under Yosys; the App-A "not-X" rules are sim-time only).

`include "apb_if.svh"

module fapb #(
    parameter int unsigned ADDR_WIDTH   = 12,
    parameter int unsigned DATA_WIDTH   = 32,
    parameter bit          F_OPT_SLVERR = 1,    // Completer may assert PSLVERR
    parameter int unsigned F_OPT_MAXSTALL = 8   // bounded-stall liveness proxy (L1)
) (
    input                   PCLK,
    input                   PRESETn,
    // Requester-driven
    input [ADDR_WIDTH-1:0]  PADDR,
    input                   PWRITE,
    input                   PSEL,
    input                   PENABLE,
    input [DATA_WIDTH-1:0]  PWDATA,
    // Completer-driven
    input                   PREADY,
    input [DATA_WIDTH-1:0]  PRDATA,
    input                   PSLVERR
);

    // ---- past-valid guard + reset bootstrap ---------------------------------
    reg f_past_valid = 1'b0;
    always @(posedge PCLK)
        f_past_valid <= 1'b1;

    // The trace must begin in reset, so the DUT's state machine and counters start from a
    // defined state (PRESETn is a free input otherwise). This is an environment constraint,
    // so a plain assume in either checker role.
    initial assume (!PRESETn);

    wire access    = PSEL && PENABLE;
    wire completing = access && PREADY;        // last cycle of a transfer

    // ========================================================================
    // Requester-side rules  (assume in Completer-checker / assert in Requester-checker)
    // ========================================================================
    always @(posedge PCLK) begin
        // P1 — reset -> idle
        if (!PRESETn) begin
            `APB_REQ (!PSEL);
            `APB_REQ (!PENABLE);
        end

        if (f_past_valid && PRESETn && $past(PRESETn)) begin
            // P4 — no enable without select
            `APB_REQ (!PENABLE || PSEL);

            // P2 — entering from IDLE: first selected cycle is SETUP (PENABLE low)
            if (!$past(PSEL) && PSEL)
                `APB_REQ (!PENABLE);

            // P3 — SETUP lasts one cycle and always moves to ACCESS
            if ($past(PSEL) && !$past(PENABLE))
                `APB_REQ (PSEL && PENABLE);

            // P5/P6 — ACCESS holds while !PREADY, deasserts the cycle after PREADY
            if ($past(PSEL) && $past(PENABLE)) begin
                if (!$past(PREADY))
                    `APB_REQ (PSEL && PENABLE);   // P5 hold
                else
                    `APB_REQ (!PENABLE);          // P6 complete -> drop enable
            end

            // P7/P8/P9 — stability of address/control/wdata through a transfer.
            // mid-transfer = was selected last cycle and did NOT complete last cycle.
            if ($past(PSEL) && !($past(PENABLE) && $past(PREADY))) begin
                `APB_REQ (PADDR  == $past(PADDR));   // P7
                `APB_REQ (PWRITE == $past(PWRITE));  // P8
                if ($past(PWRITE))
                    `APB_REQ (PWDATA == $past(PWDATA)); // P9
            end
        end
    end

    // ========================================================================
    // Completer-side rules  (assert in Completer-checker / assume in Requester-checker)
    // ========================================================================

    // L1 — bounded stall: PREADY must go HIGH within F_OPT_MAXSTALL access cycles.
    localparam int unsigned SW = (F_OPT_MAXSTALL <= 1) ? 1 : $clog2(F_OPT_MAXSTALL);
    reg [SW:0] stall;
    always @(posedge PCLK)
        if (!PRESETn)                 stall <= '0;
        else if (access && !PREADY)   stall <= stall + 1'b1;
        else                          stall <= '0;

    always @(posedge PCLK) begin
        if (PRESETn) begin
            // L1
            `APB_CMP (stall < F_OPT_MAXSTALL);

            // P13/P14 — PSLVERR only on a completing access (else LOW)
            `APB_CMP (!PSLVERR || completing);

            // If error responses are not supported, PSLVERR is tied LOW.
            if (!F_OPT_SLVERR)
                `APB_CMP (!PSLVERR);
        end
    end

    // ========================================================================
    // Cover scenarios (C1-C6) — prove the checker is not vacuous. Role-independent.
    // ========================================================================
`ifdef FAPB_COVER
    always @(posedge PCLK) if (PRESETn && f_past_valid) begin
        cover ( completing &&  PWRITE );                                  // C1 write completes
        cover ( completing && !PWRITE );                                  // C2 read completes
        cover ( access && !PREADY );                                      // C3 wait state
        if (F_OPT_SLVERR)
            cover ( completing && PSLVERR );                              // C4 error response
        cover ( $past(completing) && PSEL && !PENABLE );                  // C5 back-to-back
        cover ( $past(completing) && !PSEL );                            // C6 return to idle
    end
`endif

endmodule
