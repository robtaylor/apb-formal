// bridge_check.sv — transaction-accounting proof harness for the AHB-Lite->APB bridge (ADR 0005).
//
//   default          : DUT = libfpga ahbl_to_apb (buggy)      -> proof must FAIL (catch the bug).
//   +define+BRIDGE_SAFE : DUT = ahbl_to_apb_safe (fixed)       -> proof must PASS.
//
// A symbolic registered-output master drives the bridge; the APB side is a zero-wait completer
// (pready=1, no error), matching the reproducer's heartbeat peripheral. Two checks:
//   1. Accounting: balance = (#intended transfers) - (#APB transactions completed) >= 0.
//      The double-transaction bug drives balance negative.
//   2. APB protocol legality: fapb (Requester role) asserts the bridge speaks legal APB.

`include "apb_if.svh"

module bridge_check (
    input  wire        clk,
    input  wire        rst_n,
    // free symbolic stimulus for the master
    input  wire        go,
    input  wire [31:0] go_addr,
    input  wire        go_write,
    input  wire [31:0] go_wdata,
    input  wire [31:0] prdata_free
);
    // AHB-Lite master <-> bridge
    wire [31:0] haddr;  wire hwrite; wire [1:0] htrans;
    wire [2:0]  hsize, hburst; wire [3:0] hprot; wire hmastlock; wire [31:0] hwdata;
    wire        hready_resp, hresp; wire [31:0] hrdata;
    wire        hready = hready_resp;     // single-slave top-of-fabric tie
    wire        launch;

    // bridge -> APB completer
    wire [15:0] paddr; wire psel, penable, pwrite; wire [31:0] pwdata;
    wire        pready  = 1'b1;           // zero-wait completer
    wire        pslverr = 1'b0;
    wire [31:0] prdata  = prdata_free;

    ahbl_master_model #(.W_HADDR(32), .W_DATA(32)) m (
        .clk(clk), .rst_n(rst_n),
        .go(go), .go_addr(go_addr), .go_write(go_write), .go_wdata(go_wdata),
        .haddr(haddr), .hwrite(hwrite), .htrans(htrans), .hsize(hsize), .hburst(hburst),
        .hprot(hprot), .hmastlock(hmastlock), .hwdata(hwdata), .hready(hready),
        .launch(launch)
    );

`ifdef BRIDGE_SAFE
    ahbl_to_apb_safe #(.W_HADDR(32), .W_PADDR(16), .W_DATA(32), .FULL_RESET(1)) dut (
`else
    ahbl_to_apb      #(.W_HADDR(32), .W_PADDR(16), .W_DATA(32), .FULL_RESET(1)) dut (
`endif
        .clk(clk), .rst_n(rst_n),
        .ahbls_haddr(haddr), .ahbls_hwrite(hwrite), .ahbls_htrans(htrans),
        .ahbls_hsize(hsize), .ahbls_hburst(hburst), .ahbls_hprot(hprot),
        .ahbls_hmastlock(hmastlock), .ahbls_hwdata(hwdata), .ahbls_hready(hready),
        .ahbls_hready_resp(hready_resp), .ahbls_hresp(hresp), .ahbls_hrdata(hrdata),
        .apbm_paddr(paddr), .apbm_psel(psel), .apbm_penable(penable), .apbm_pwrite(pwrite),
        .apbm_pwdata(pwdata), .apbm_pready(pready), .apbm_prdata(prdata), .apbm_pslverr(pslverr)
    );

    // --- APB protocol legality of the bridge's APB master port -------------------------------
    fapb #(
        .ADDR_WIDTH(16), .DATA_WIDTH(32),
        .F_OPT_ROLE(`FAPB_REQUESTER_CHECK),
        .F_OPT_SLVERR(1), .F_OPT_SLVERR_STRICT(1), .F_OPT_LIVENESS(0)
    ) apbchk (
        .PCLK(clk), .PRESETn(rst_n),
        .PADDR(paddr), .PWRITE(pwrite), .PSEL(psel), .PENABLE(penable), .PWDATA(pwdata),
        .PREADY(pready), .PRDATA(prdata), .PSLVERR(pslverr)
    );

    // --- Transaction accounting (the headline property) --------------------------------------
    initial assume (!rst_n);             // start in reset

    wire apb_done = psel && penable && pready;   // 1-cycle APB-completion pulse

    // balance = intended - completed. >= 0 means "no APB transaction the master didn't intend".
    reg signed [2:0] bal;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) bal <= 3'sd0;
        else        bal <= bal + (launch ? 3'sd1 : 3'sd0) - (apb_done ? 3'sd1 : 3'sd0);

    always @(posedge clk) begin
        if (rst_n) begin
            assert (bal >= 0);           // <-- the double-transaction bug drives this negative
            assert (bal <= 3'sd2);       // bounded inflight (state bound for k-induction)
        end
    end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
