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
    
     /////////QDRIIA/////////
`ifdef ENABLE_QDRIIA
     output [19:0] qdriia_mem_a,
     output [1:0]  qdriia_mem_bws_n,
     input         qdriia_mem_cq_n,
     input         qdriia_mem_cq,
     output [17:0] qdriia_mem_d,
     output        qdriia_mem_doff_n,
     output        qdriia_mem_k_n,
     output        qdriia_mem_k,
     output        qdriia_mem_odt,
     input [17:0]  qdriia_mem_q,
     input         qdriia_mem_qvld,
     output        qdriia_mem_rps_n,
     output        qdriia_mem_wps_n,
`endif

     /////////QDRIIB/////////
`ifdef ENABLE_QDRIIB
     output [19:0] qdriib_mem_a,
     output [1:0]  qdriib_mem_bws_n,
     input         qdriib_mem_cq_n,
     input         qdriib_mem_cq,
     output [17:0] qdriib_mem_d,
     output        qdriib_mem_doff_n,
     output        qdriib_mem_k_n,
     output        qdriib_mem_k,
     output        qdriib_mem_odt,
     input [17:0]  qdriib_mem_q,
     input         qdriib_mem_qvld,
     output        qdriib_mem_rps_n,
     output        qdriib_mem_wps_n,
     /// RZQ ///
     input         qdriib_mem_oct_rzqin,
`endif

     /////////QDRIIC/////////
`ifdef ENABLE_QDRIIC
     output [19:0] qdriic_mem_a,
     output [1:0]  qdriic_mem_bws_n,
     input         qdriic_mem_cq_n,
     input         qdriic_mem_cq,
     output [17:0] qdriic_mem_d,
     output        qdriic_mem_doff_n,
     output        qdriic_mem_k_n,
     output        qdriic_mem_k,
     output        qdriic_mem_odt,
     input [17:0]  qdriic_mem_q,
     input         qdriic_mem_qvld,
     output        qdriic_mem_rps_n,
     output        qdriic_mem_wps_n,
`endif

     /////////QDRIID/////////
`ifdef ENABLE_QDRIID
     output [19:0] qdriid_mem_a,
     output [1:0]  qdriid_mem_bws_n,
     input         qdriid_mem_cq_n,
     input         qdriid_mem_cq,
     output [17:0] qdriid_mem_d,
     output        qdriid_mem_doff_n,
     output        qdriid_mem_k_n,
     output        qdriid_mem_k,
     output        qdriid_mem_odt,
     input [17:0]  qdriid_mem_q,
     input         qdriid_mem_qvld,
     output        qdriid_mem_rps_n,
     output        qdriid_mem_wps_n,
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
