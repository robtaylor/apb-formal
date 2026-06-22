// ahbl_to_apb_safe.sv — patched copy of libfpga busfabric/ahbl_to_apb.v (WTFPL, Luke Wren).
//
// Applies the one-cycle "post-retire" bubble fix for the double-transaction bug documented in
// the reproducer (/Users/roberttaylor/Code/libfpga-ahbl-to-apb-bug, README "Proposed fix"):
// add S_POSTWR/S_POSTRD between the dphase-complete states and S_READY, and assert
// hready_resp during them — so the bridge cannot re-decode a stale address phase from a
// registered-output master. Diff vs the upstream file: W_APB_STATE 3->4, two new states, the
// S_WR2/S_RD1 retire targets, and the hready_resp term. Everything else is verbatim.

`default_nettype none

module ahbl_to_apb_safe #(
	parameter W_HADDR = 32,
	parameter W_PADDR = 16,
	parameter W_DATA = 32,
	parameter FULL_RESET = 1
) (
	input wire clk,
	input wire rst_n,

	input  wire [W_HADDR-1:0] ahbls_haddr,
	input  wire               ahbls_hwrite,
	input  wire [1:0]         ahbls_htrans,
	input  wire [2:0]         ahbls_hsize,
	input  wire [2:0]         ahbls_hburst,
	input  wire [3:0]         ahbls_hprot,
	input  wire               ahbls_hmastlock,
	input  wire [W_DATA-1:0]  ahbls_hwdata,
	input  wire               ahbls_hready,
	output reg                ahbls_hready_resp,
	output reg                ahbls_hresp,
	output reg  [W_DATA-1:0]  ahbls_hrdata,

	output reg  [W_PADDR-1:0] apbm_paddr,
	output reg                apbm_psel,
	output reg                apbm_penable,
	output reg                apbm_pwrite,
	output reg  [W_DATA-1:0]  apbm_pwdata,
	input wire                apbm_pready,
	input wire  [W_DATA-1:0]  apbm_prdata,
	input wire                apbm_pslverr
);

// Transfer state machine

localparam W_APB_STATE = 4;
localparam S_READY   = 4'd0; // Idle upstream dphase or end of read/write dphase
localparam S_RD0     = 4'd1; // Downstream setup phase (cannot stall)
localparam S_RD1     = 4'd2; // Downstream access phase (may stall or error)
localparam S_WR0     = 4'd3; // Sample hwdata
localparam S_WR1     = 4'd4; // Downstream setup phase (cannot stall)
localparam S_WR2     = 4'd5; // Downstream access phase (may stall or error)
localparam S_ERR0    = 4'd6; // AHBL error response, first cycle
localparam S_ERR1    = 4'd7; // AHBL error response, accept new aphase if not deasserted
localparam S_POSTWR  = 4'd8; // FIX: one-cycle bubble after S_WR2 retire
localparam S_POSTRD  = 4'd9; // FIX: one-cycle bubble after S_RD1 retire

reg [W_APB_STATE-1:0] apb_state;
reg [W_APB_STATE-1:0] apb_state_nxt;

wire [W_APB_STATE-1:0] aphase_to_dphase =
	ahbls_htrans[1] &&  ahbls_hwrite ? S_WR0 :
	ahbls_htrans[1] && !ahbls_hwrite ? S_RD0 : S_READY;

always @ (*) begin
	apb_state_nxt = apb_state;
	 case (apb_state)
		S_READY:  if (ahbls_hready) apb_state_nxt = aphase_to_dphase;
		S_WR0:                      apb_state_nxt = S_WR1;
		S_WR1:                      apb_state_nxt = S_WR2;
		S_WR2:    if (apbm_pready)  apb_state_nxt = apbm_pslverr ? S_ERR0 : S_POSTWR;
		S_RD0:                      apb_state_nxt = S_RD1;
		S_RD1:    if (apbm_pready)  apb_state_nxt = apbm_pslverr ? S_ERR0 : S_POSTRD;
		S_POSTWR:                   apb_state_nxt = S_READY;
		S_POSTRD:                   apb_state_nxt = S_READY;
		S_ERR0:                     apb_state_nxt = S_ERR1;
		S_ERR1:                     apb_state_nxt = aphase_to_dphase;
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		apb_state <= S_READY;
		ahbls_hready_resp <= 1'b1;
		ahbls_hresp <= 1'b0;
	end else begin
		apb_state <= apb_state_nxt;
		ahbls_hready_resp <=
			apb_state_nxt == S_READY  ||
			apb_state_nxt == S_ERR1   ||
			apb_state_nxt == S_POSTWR ||
			apb_state_nxt == S_POSTRD;
		ahbls_hresp <=
			apb_state_nxt == S_ERR0 ||
			apb_state_nxt == S_ERR1;
	end
end

// Downstream request

always @ (*) begin
	case (apb_state)
		S_RD0:   {apbm_psel, apbm_penable, apbm_pwrite} = 3'b100;
		S_RD1:   {apbm_psel, apbm_penable, apbm_pwrite} = 3'b110;
		S_WR1:   {apbm_psel, apbm_penable, apbm_pwrite} = 3'b101;
		S_WR2:   {apbm_psel, apbm_penable, apbm_pwrite} = 3'b111;
		default: {apbm_psel, apbm_penable, apbm_pwrite} = 3'b000;
	endcase
end

generate
if (FULL_RESET != 0) begin: reg_downstream_reset
	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			apbm_paddr <= {W_PADDR{1'b0}};
			apbm_pwdata <= {W_DATA{1'b0}};
		end else begin
			if (ahbls_htrans[1] && ahbls_hready)
				apbm_paddr <= ahbls_haddr[W_PADDR-1:0];
			if (apb_state == S_WR0)
				apbm_pwdata <= ahbls_hwdata;
		end
	end
end else begin: reg_downstream_noreset
	always @ (posedge clk) begin
		if (ahbls_htrans[1] && ahbls_hready) begin
			apbm_paddr <= ahbls_haddr[W_PADDR-1:0];
		end
		if (apb_state == S_WR0) begin
			apbm_pwdata <= ahbls_hwdata;
		end
	end
end
endgenerate

// Upstream response
generate
if (FULL_RESET != 0) begin: reg_upstream_reset
	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			ahbls_hrdata <= {W_DATA{1'b0}};
		end else if (apb_state == S_RD1 && apbm_pready) begin
			ahbls_hrdata <= apbm_prdata;
		end
	end
end else begin: reg_upstream_noreset
	always @ (posedge clk) begin
		ahbls_hrdata <= apbm_prdata;
	end
end
endgenerate

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
