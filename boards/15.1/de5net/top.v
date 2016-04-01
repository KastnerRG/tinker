
module top(

   //////// CLOCK //////////
   input config_clk,  // 50MHz clock 
   input Mem0_RefClk, // 50MHz clock
   input Mem1_RefClk, // 50MHz clock
//   input kernel_pll_refclk_clk, // 50MHz clock


   //////// Power //////////
//   output USER_1P35V_EN,
//   output MARGIN_EN,
//   output MARGIN_HIGH,

   //////// PCIe //////////
   input        pcie_refclk,
   input        perstl0_n,  // Reset to embedded PCIe
   input        hip_serial_rx_in0,
   input        hip_serial_rx_in1,
   input        hip_serial_rx_in2,
   input        hip_serial_rx_in3,
`ifdef PCIE_8LANES
   input        hip_serial_rx_in4,
   input        hip_serial_rx_in5,
   input        hip_serial_rx_in6,
   input        hip_serial_rx_in7,
`endif
   output       hip_serial_tx_out0,
   output       hip_serial_tx_out1,
   output       hip_serial_tx_out2,
   output       hip_serial_tx_out3,
`ifdef PCIE_8LANES
   output       hip_serial_tx_out4,
   output       hip_serial_tx_out5,
   output       hip_serial_tx_out6,
   output       hip_serial_tx_out7,
`endif


`ifndef MEM0_DISABLED
   //////// DDR3 //////////
   output        Mem0_Reset_n,
   output [15:0] Mem0_Addr,
   output [2:0]  Mem0_Bank,
   output        Mem0_Cas_n,
   output        Mem0_Cke,
   output        Mem0_Ck,
   output        Mem0_Ck_n,
   output        Mem0_Cs_n,
   output [7:0]  Mem0_Dm,
   inout [63:0]  Mem0_Dq,
   inout  [7:0]  Mem0_Dqs,
   inout  [7:0]  Mem0_Dqs_n,
   output        Mem0_Odt,
   output        Mem0_Ras_n,
   output        Mem0_We_n,
   input         Mem0_Rzq,
`endif

`ifndef MEM1_DISABLED
   //////// DDR3 //////////
   output        Mem1_Reset_n,
   output [15:0] Mem1_Addr,
   output [2:0]  Mem1_Bank,
   output        Mem1_Cas_n,
   output        Mem1_Cke,
   output        Mem1_Ck,
   output        Mem1_Ck_n,
   output        Mem1_Cs_n,
   output [7:0]  Mem1_Dm,
   inout [63:0]  Mem1_Dq,
   inout  [7:0]  Mem1_Dqs,
   inout  [7:0]  Mem1_Dqs_n,
   output        Mem1_Odt,
   output        Mem1_Ras_n,
   output        Mem1_We_n,
   input         Mem1_Rzq,
`endif

   //////// LED //////////
   output [7:0] leds
);

//=======================================================
//  PARAMETER declarations
//=======================================================

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire resetn;
wire npor;


//=======================================================
//  Board-specific 
//=======================================================

//assign USER_1P35V_EN = 1'b1;  // Force 1.35V supply on
//assign MARGIN_EN = 1'b1;
//assign MARGIN_HIGH = 1'b1;

//=======================================================
//  Reset logic 
//=======================================================
assign resetn = 1'b1;

//=======================================================
//  System instantiation
//=======================================================

system system_inst 
(
   // Global signals
   .global_reset_reset_n( resetn ),  // No hard reset !!!
   .config_clk_clk( config_clk ),
`ifndef MEM0_DISABLED
   .ddr3a_pll_ref_clk( Mem0_RefClk ),
`endif
`ifndef MEM1_DISABLED
   .ddr3b_pll_ref_clk( Mem1_RefClk ),
`endif

   // PCIe pins
   .pcie_npor_pin_perst(perstl0_n),
   .pcie_npor_npor(1'b1),
   .pcie_npor_out_reset_n(npor),
   .pcie_refclk_clk( pcie_refclk ),
   .pcie_rx_in0( hip_serial_rx_in0 ),
   .pcie_rx_in1( hip_serial_rx_in1 ),
   .pcie_rx_in2( hip_serial_rx_in2 ),
   .pcie_rx_in3( hip_serial_rx_in3 ),
`ifdef PCIE_8LANES
   .pcie_rx_in4( hip_serial_rx_in4 ),
   .pcie_rx_in5( hip_serial_rx_in5 ),
   .pcie_rx_in6( hip_serial_rx_in6 ),
   .pcie_rx_in7( hip_serial_rx_in7 ),
`endif
   .pcie_tx_out0( hip_serial_tx_out0 ),
   .pcie_tx_out1( hip_serial_tx_out1 ),
   .pcie_tx_out2( hip_serial_tx_out2 ),
   .pcie_tx_out3( hip_serial_tx_out3 ),
`ifdef PCIE_8LANES
   .pcie_tx_out4( hip_serial_tx_out4 ),
   .pcie_tx_out5( hip_serial_tx_out5 ),
   .pcie_tx_out6( hip_serial_tx_out6 ),
   .pcie_tx_out7( hip_serial_tx_out7 ),
`endif

`ifndef Mem0_DISABLED  //DDR3A -> Bank 8
   // DDR3 pins
   .ddr3a_mem_reset_n( Mem0_Reset_n ),
   .ddr3a_mem_a( Mem0_Addr ),
   .ddr3a_mem_ba( Mem0_Bank ),
   .ddr3a_mem_cas_n( Mem0_Cas_n ),
   .ddr3a_mem_ck( Mem0_Ck ),
   .ddr3a_mem_ck_n( Mem0_Ck_n ),
   .ddr3a_mem_cke( Mem0_Cke ),
   .ddr3a_mem_cs_n( Mem0_Cs_n ),
   .ddr3a_mem_dm( Mem0_Dm ),
   .ddr3a_mem_dq( Mem0_Dq ),
   .ddr3a_mem_dqs_n( Mem0_Dqs_n ),
   .ddr3a_mem_dqs( Mem0_Dqs ),
   .ddr3a_mem_oct_rzqin( Mem0_Rzq ),
   .ddr3a_mem_odt( Mem0_Odt ),
   .ddr3a_mem_ras_n( Mem0_Ras_n ),
   .ddr3a_mem_we_n( Mem0_We_n ),
`endif

   // DDR3 pins
`ifndef Mem1_DISABLED  //DDR3B -> Bank7
   .ddr3b_mem_reset_n( Mem1_Reset_n ),
   .ddr3b_mem_a( Mem1_Addr ),
   .ddr3b_mem_ba( Mem1_Bank ),
   .ddr3b_mem_cas_n( Mem1_Cas_n ),
   .ddr3b_mem_ck( Mem1_Ck ),
   .ddr3b_mem_ck_n( Mem1_Ck_n ),
   .ddr3b_mem_cke( Mem1_Cke ),
   .ddr3b_mem_cs_n( Mem1_Cs_n ),
   .ddr3b_mem_dm( Mem1_Dm ),
   .ddr3b_mem_dq( Mem1_Dq ),
   .ddr3b_mem_dqs_n( Mem1_Dqs_n ),
   .ddr3b_mem_dqs( Mem1_Dqs ),
   .ddr3b_mem_oct_rzqin( Mem1_Rzq ),
   .ddr3b_mem_odt( Mem1_Odt ),
   .ddr3b_mem_ras_n( Mem1_Ras_n ),
   .ddr3b_mem_we_n( Mem1_We_n ),
`endif

`ifdef CVPFIX
   .reconfig_to_xcvr_reconfig_to_xcvr({
`ifdef PCIE_8LANES
                              10
                            `else
                              5
`endif
                              {24'h0, 2'b11, 44'h0}}),
   .reconfig_from_xcvr_reconfig_from_xcvr(),
`endif

   .kernel_pll_refclk_clk( Mem0_RefClk )
);

`ifndef MEM0_DISABLED
`ifndef MEM_8GB
assign Mem0_Addr[15] = 1'b0;
`ifndef MEM_4GB
assign Mem0_Addr[14] = 1'b0;
`endif
`endif
`endif

`ifndef MEM1_DISABLED
`ifndef MEM_8GB
assign Mem1_Addr[15] = 1'b0;
`ifndef MEM_4GB
assign Mem1_Addr[14] = 1'b0;
`endif
`endif
`endif

assign leds[7:0] = 8'b0101000;

endmodule
