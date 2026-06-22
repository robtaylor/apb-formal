// fapb.sv — APB-lite + APB3 protocol-compliance checker (ADR 0001/0002/0003).
//
// A property module to attach (by instantiation in an SBY wrapper — NOT `bind`) to an APB
// Requester or Completer. Every property is tagged [cat <id> | <spec §/fig>] mapping it to a
// row in docs/spec/property-catalog.md and a clause of Arm IHI0024E (captured in
// docs/spec/IHI0024E.md).
//
//   F_OPT_ROLE = FAPB_COMPLETER_CHECK (default) : assume a legal Requester, assert the Completer.
//   F_OPT_ROLE = FAPB_REQUESTER_CHECK            : flip — assert the Requester, assume the Completer.
//
// Role is a parameter (not a compile define) so multiple instances with different roles can
// coexist in one elaboration (e.g. apb_splitter's upstream Completer + N downstream Requester
// ports at once). See ADR 0003 §Amendment.
//
// Style: immediate assertions in a clocked block using $past/$stable; 2-state SMT semantics
// (no $isunknown X-checks — vacuous under Yosys; the App-A "not-X" rules P10-P12 are sim-time
// only, see ADR 0001).
//
// Parameters that gate properties:
//   F_OPT_SLVERR        : Completer may drive PSLVERR at all (else it is tied LOW).
//   F_OPT_SLVERR_STRICT : enforce the §3.4 PSLVERR-LOW-when-not-completing *recommendation*
//                         (P13/P14). Set 0 for RTL that drives PSLVERR ungated by PSEL (legal
//                         per §3.4, just not recommended — e.g. libfpga apb_splitter).
//   F_OPT_LIVENESS      : assert/assume the bounded-stall liveness proxy L1. This is a
//                         design-specific bound, NOT a spec rule (§3.3.2 permits unbounded
//                         waits), so disable it where the spec's unbounded semantics matter
//                         (e.g. an environment Completer in a requester/splitter proof).

`include "apb_if.svh"

module fapb #(
    parameter int unsigned ADDR_WIDTH          = 12,
    parameter int unsigned DATA_WIDTH          = 32,
    parameter int unsigned F_OPT_ROLE          = `FAPB_COMPLETER_CHECK,
    parameter bit          F_OPT_SLVERR        = 1,
    parameter bit          F_OPT_SLVERR_STRICT = 1,
    parameter bit          F_OPT_LIVENESS      = 1,
    parameter int unsigned F_OPT_MAXSTALL      = 8
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
    // defined state (PRESETn is a free input otherwise). Environment constraint -> assume.
    initial assume (!PRESETn);

    wire access     = PSEL && PENABLE;
    wire completing = access && PREADY;        // last cycle of a transfer

    // ========================================================================
    // Requester-side rules  (assume in Completer-checker / assert in Requester-checker)
    // ========================================================================
    always @(posedge PCLK) begin
        // P1 [cat P1 | §4, App B]: reset -> IDLE (PSEL & PENABLE low).
        if (!PRESETn) begin
            `APB_REQ (!PSEL);
            `APB_REQ (!PENABLE);
        end

        if (f_past_valid && PRESETn && $past(PRESETn)) begin
            // P4 [cat P4 | §4]: no ACCESS without select (PENABLE -> PSEL).
            `APB_REQ (!PENABLE || PSEL);

            // P2 [cat P2 | §3.1.1, Fig 4-1]: entering from IDLE, first selected cycle is
            // SETUP (PENABLE low).
            if (!$past(PSEL) && PSEL) begin
                `APB_REQ (!PENABLE);
            end

            // P3 [cat P3 | §4]: SETUP lasts exactly one cycle and always moves to ACCESS.
            if ($past(PSEL) && !$past(PENABLE)) begin
                `APB_REQ (PSEL && PENABLE);
            end

            // P5/P6 [cat P5,P6 | §3.1.2, §3.3.2, §4]: ACCESS holds while PREADY low (P5), and
            // PENABLE deasserts the cycle after PREADY high (P6). Together: PSEL/PENABLE are
            // held HIGH through every wait cycle (covers the §3.1.2/§3.3.2 PSELx/PENABLE
            // "remain unchanged while PREADY LOW" requirement).
            if ($past(PSEL) && $past(PENABLE)) begin
                if (!$past(PREADY)) begin
                    `APB_REQ (PSEL && PENABLE);   // P5 hold
                end else begin
                    `APB_REQ (!PENABLE);          // P6 complete -> drop enable
                end
            end

            // P7/P8/P9 [cat P7,P8,P9 | §3.1.2, §3.3.2, §4]: address/control/wdata stable from
            // SETUP through ACCESS until completion. The window "was selected last cycle and did
            // NOT complete last cycle" starts at SETUP and ends at completion, so back-to-back
            // transfers are not over-constrained.
            if ($past(PSEL) && !($past(PENABLE) && $past(PREADY))) begin
                `APB_REQ (PADDR  == $past(PADDR));   // P7
                `APB_REQ (PWRITE == $past(PWRITE));  // P8
                if ($past(PWRITE)) begin
                    `APB_REQ (PWDATA == $past(PWDATA)); // P9 (write only)
                end
            end
        end
    end

    // ========================================================================
    // Completer-side rules  (assert in Completer-checker / assume in Requester-checker)
    // ========================================================================

    // L1 [cat L1 | NOT a spec rule]: bounded-stall liveness proxy. §3.3.2 permits any number of
    // wait cycles ("from zero upwards"), so this is a design-specific bound, gated by
    // F_OPT_LIVENESS. PREADY is otherwise left free when not in an access (matches §3.1.2
    // "PREADY can take any value when PENABLE is LOW").
    localparam int unsigned SW = (F_OPT_MAXSTALL <= 1) ? 1 : $clog2(F_OPT_MAXSTALL);
    reg [SW:0] stall;
    always @(posedge PCLK)
        if (!PRESETn)                 stall <= '0;
        else if (access && !PREADY)   stall <= stall + 1'b1;
        else                          stall <= '0;

    always @(posedge PCLK) begin
        if (PRESETn) begin
            if (F_OPT_LIVENESS) begin
                `APB_CMP (stall < F_OPT_MAXSTALL);   // L1
            end

            // P13/P14 [cat P13,P14 | §3.4]: the §3.4 *recommendation* that PSLVERR is driven LOW
            // unless the transfer is completing. NOTE: §3.4's "only considered valid in the last
            // cycle" governs the *consumer*; the only *driver* obligation is this recommendation
            // ("recommended, but not required"). Split into two diagnosable tiers, both gated by
            // F_OPT_SLVERR_STRICT:
            if (F_OPT_SLVERR_STRICT) begin
                `APB_CMP (!PSLVERR || access);   // P13: PSLVERR confined to an ACCESS phase
                `APB_CMP (!PSLVERR || PREADY);   // P14: ... and to the completing (PREADY) cycle
            end

            // PSLVERR tied LOW when error responses are unsupported (§3.4; App B default 0b0).
            if (!F_OPT_SLVERR) begin
                `APB_CMP (!PSLVERR);
            end
        end
    end

    // ========================================================================
    // Cover scenarios (C1-C6 | Figs 3-1/3-4/3-2/3-5/3-6/3-7, §3.1, §4). Role-independent.
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
