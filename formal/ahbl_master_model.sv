// ahbl_master_model.sv — symbolic registered-output AHB-Lite master (ADR 0005).
//
// A closed FSM that issues a nondeterministic sequence of single (non-burst) AHB-Lite transfers
// with REGISTERED outputs — the Hazard3-class timing that exposes the ahbl_to_apb bug: it holds
// the address phase one cycle past HREADY rising before updating. Lifted from the reproducer's
// TB master stub (/Users/roberttaylor/Code/libfpga-ahbl-to-apb-bug/tb_ahbl_to_apb.v), with the
// hardcoded single write replaced by free per-transfer choices.
//
// AHB-Lite single-transfer legality is STRUCTURAL (the FSM holds aphase until HREADY, updates one
// cycle later), so no separate protocol-assumption layer is needed. `launch` is a 1-cycle pulse
// marking each transfer the master *intends* — the ground truth the accounting property counts.

`default_nettype none

module ahbl_master_model #(
    parameter integer W_HADDR = 32,
    parameter integer W_DATA  = 32
) (
    input  wire               clk,
    input  wire               rst_n,
    // free symbolic stimulus (solver-driven)
    input  wire               go,        // when idle, launch a new transfer
    input  wire [W_HADDR-1:0] go_addr,
    input  wire               go_write,
    input  wire [W_DATA-1:0]  go_wdata,
    // AHB-Lite master outputs (registered)
    output reg  [W_HADDR-1:0] haddr,
    output reg                hwrite,
    output reg  [1:0]         htrans,
    output reg  [2:0]         hsize,
    output reg  [2:0]         hburst,
    output reg  [3:0]         hprot,
    output reg                hmastlock,
    output reg  [W_DATA-1:0]  hwdata,
    input  wire               hready,     // from bridge (looped hready_resp)
    // verification hook: 1-cycle pulse when a NEW transfer is committed
    output wire               launch
);
    localparam [1:0] HTRANS_IDLE = 2'b00, HTRANS_NONSEQ = 2'b10;
    localparam M_IDLE = 1'b0, M_APHASE = 1'b1;

    reg m_state;
    reg dphase_seen;   // have we seen the bridge enter its dphase wait (hready low) yet?

    // Intent: committed the cycle we decide to launch (while idle).
    assign launch = rst_n && (m_state == M_IDLE) && go;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            haddr       <= {W_HADDR{1'b0}};
            hwrite      <= 1'b0;
            htrans      <= HTRANS_IDLE;
            hsize       <= 3'd2;        // word
            hburst      <= 3'd0;        // SINGLE
            hprot       <= 4'b0011;
            hmastlock   <= 1'b0;
            hwdata      <= {W_DATA{1'b0}};
            m_state     <= M_IDLE;
            dphase_seen <= 1'b0;
        end else begin
            case (m_state)
                M_IDLE: begin
                    if (go) begin
                        haddr       <= go_addr;
                        hwrite      <= go_write;
                        htrans      <= HTRANS_NONSEQ;
                        hwdata      <= go_wdata;   // valid from aphase through dphase
                        dphase_seen <= 1'b0;
                        m_state     <= M_APHASE;
                    end
                end

                M_APHASE: begin
                    // Bridge entered its dphase wait once we see hready low.
                    if (!hready)
                        dphase_seen <= 1'b1;

                    // Registered-output retire: the cycle we sample hready=1 (after the dphase),
                    // our outputs are UNCHANGED on the bus; they update on the NEXT edge. This
                    // one-cycle lag is exactly the window the bridge bug exploits.
                    if (dphase_seen && hready) begin
                        haddr   <= {W_HADDR{1'b0}};
                        hwrite  <= 1'b0;
                        htrans  <= HTRANS_IDLE;
                        hwdata  <= {W_DATA{1'b0}};
                        m_state <= M_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
