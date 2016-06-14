`include "tinker.vh"
module top
    (
     ///////// OSC ////////
     input         OSC_50_B3B,
     input         OSC_50_B3D,
     input         OSC_50_B4A,
     input         OSC_50_B4D,
     input         OSC_50_B7A,
     input         OSC_50_B7D,
     input         OSC_50_B8A,
     input         OSC_50_B8D,

     //////// PCIe //////////
     input         pcie_refclk,
     input         pcie_reset_n, // Reset to embedded PCIe
     input         pcie_rx_in0,
     input         pcie_rx_in1,
     input         pcie_rx_in2,
     input         pcie_rx_in3,
     input         pcie_rx_in4,
     input         pcie_rx_in5,
     input         pcie_rx_in6,
     input         pcie_rx_in7,
     output        pcie_tx_out0,
     output        pcie_tx_out1,
     output        pcie_tx_out2,
     output        pcie_tx_out3,
     output        pcie_tx_out4,
     output        pcie_tx_out5,
     output        pcie_tx_out6,
     output        pcie_tx_out7,

     //////// DDR3 //////////
`ifdef ENABLE_DDR3_A
     output        ddr3_a_mem_reset_n,
     output [14:0] ddr3_a_mem_a,
     output [2:0]  ddr3_a_mem_ba,
     output        ddr3_a_mem_cas_n,
     output        ddr3_a_mem_cke,
     output        ddr3_a_mem_ck,
     output        ddr3_a_mem_ck_n,
     output        ddr3_a_mem_cs_n,
     output [7:0]  ddr3_a_mem_dm,
     inout [63:0]  ddr3_a_mem_dq,
     inout [7:0]   ddr3_a_mem_dqs,
     inout [7:0]   ddr3_a_mem_dqs_n,
     output        ddr3_a_mem_odt,
     output        ddr3_a_mem_ras_n,
     output        ddr3_a_mem_we_n,
     input         ddr3_a_mem_oct_rzqin,
`endif

     //////// DDR3 //////////
`ifdef ENABLE_DDR3_B
     output        ddr3_b_mem_reset_n,
     output [14:0] ddr3_b_mem_a,
     output [2:0]  ddr3_b_mem_ba,
     output        ddr3_b_mem_cas_n,
     output        ddr3_b_mem_cke,
     output        ddr3_b_mem_ck,
     output        ddr3_b_mem_ck_n,
     output        ddr3_b_mem_cs_n,
     output [7:0]  ddr3_b_mem_dm,
     inout [63:0]  ddr3_b_mem_dq,
     inout [7:0]   ddr3_b_mem_dqs,
     inout [7:0]   ddr3_b_mem_dqs_n,
     output        ddr3_b_mem_odt,
     output        ddr3_b_mem_ras_n,
     output        ddr3_b_mem_we_n,
     input         ddr3_b_mem_oct_rzqin,
`endif
    
     /////////QDRII_A/////////
`ifdef ENABLE_QDRII_A
     output [19:0] qdrii_a_mem_a,
     output [1:0]  qdrii_a_mem_bws_n,
     input         qdrii_a_mem_cq_n,
     input         qdrii_a_mem_cq,
     output [17:0] qdrii_a_mem_d,
     output        qdrii_a_mem_doff_n,
     output        qdrii_a_mem_k_n,
     output        qdrii_a_mem_k,
     output        qdrii_a_mem_odt,
     input [17:0]  qdrii_a_mem_q,
     input         qdrii_a_mem_qvld,
     output        qdrii_a_mem_rps_n,
     output        qdrii_a_mem_wps_n,
`endif

     /////////QDRII_B/////////
`ifdef ENABLE_QDRII_B
     output [19:0] qdrii_b_mem_a,
     output [1:0]  qdrii_b_mem_bws_n,
     input         qdrii_b_mem_cq_n,
     input         qdrii_b_mem_cq,
     output [17:0] qdrii_b_mem_d,
     output        qdrii_b_mem_doff_n,
     output        qdrii_b_mem_k_n,
     output        qdrii_b_mem_k,
     output        qdrii_b_mem_odt,
     input [17:0]  qdrii_b_mem_q,
     input         qdrii_b_mem_qvld,
     output        qdrii_b_mem_rps_n,
     output        qdrii_b_mem_wps_n,
     /// RZQ ///
     input         qdrii_b_mem_oct_rzqin,
`endif

     /////////QDRII_C/////////
`ifdef ENABLE_QDRII_C
     output [19:0] qdrii_c_mem_a,
     output [1:0]  qdrii_c_mem_bws_n,
     input         qdrii_c_mem_cq_n,
     input         qdrii_c_mem_cq,
     output [17:0] qdrii_c_mem_d,
     output        qdrii_c_mem_doff_n,
     output        qdrii_c_mem_k_n,
     output        qdrii_c_mem_k,
     output        qdrii_c_mem_odt,
     input [17:0]  qdrii_c_mem_q,
     input         qdrii_c_mem_qvld,
     output        qdrii_c_mem_rps_n,
     output        qdrii_c_mem_wps_n,
`endif

     /////////QDRII_D/////////
`ifdef ENABLE_QDRII_D
     output [19:0] qdrii_d_mem_a,
     output [1:0]  qdrii_d_mem_bws_n,
     input         qdrii_d_mem_cq_n,
     input         qdrii_d_mem_cq,
     output [17:0] qdrii_d_mem_d,
     output        qdrii_d_mem_doff_n,
     output        qdrii_d_mem_k_n,
     output        qdrii_d_mem_k,
     output        qdrii_d_mem_odt,
     input [17:0]  qdrii_d_mem_q,
     input         qdrii_d_mem_qvld,
     output        qdrii_d_mem_rps_n,
     output        qdrii_d_mem_wps_n,
`endif

     //////// LED //////////
     output [7:0]  leds);

    //=======================================================
    //  PARAMETER declarations
    //=======================================================

    //=======================================================
    //  REG/WIRE declarations
    //=======================================================
    wire           resetn;
    wire           npor;

    wire           ddr3_a_pll_ref_clk;
    wire           ddr3_b_pll_ref_clk;
    wire           config_clk_clk;
    wire           kernel_pll_refclk_clk;
    wire           qdrii_b_pll_ref_clk;
    wire           qdrii_d_pll_ref_clk;

    //=======================================================
    //  Board-specific 
    //=======================================================

    assign ddr3_a_pll_ref_clk = OSC_50_B8A;
    assign ddr3_b_pll_ref_clk = OSC_50_B7A;
    assign config_clk_clk = OSC_50_B3B;
    assign qdrii_b_pll_ref_clk = OSC_50_B4A;
    assign qdrii_d_pll_ref_clk = OSC_50_B8D;
    assign kernel_pll_refclk_clk = OSC_50_B3D;

    //=======================================================
    //  Reset logic 
    //=======================================================
    assign resetn = 1'b1;

    //=======================================================
    //  System instantiation
    //=======================================================

    system system_inst 
        (
         .*,
         // Global signals
         .global_reset_reset_n( resetn ),  // No hard reset !!!
         // PCIe pins
         .pcie_npor_pin_perst(pcie_reset_n),
         .pcie_npor_npor(1'b1),
         .pcie_npor_out_reset_n(npor),
         .pcie_refclk_clk( pcie_refclk ),
         .reconfig_to_xcvr_reconfig_to_xcvr({10{24'h0, 2'b11, 44'h0}}),
         .reconfig_from_xcvr_reconfig_from_xcvr());

    assign leds[7:0] = 8'b0101000;

endmodule
