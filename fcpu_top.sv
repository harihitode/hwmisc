`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu_top
  (
   // serial
   input         uart_txd_in,
   output        uart_rxd_out,
   // DDR
   inout [15:0]  ddr3_dq,
   inout [1:0]   ddr3_dqs_n,
   inout [1:0]   ddr3_dqs_p,
   // Outputs
   output [13:0] ddr3_addr,
   output [2:0]  ddr3_ba,
   output        ddr3_ras_n,
   output        ddr3_cas_n,
   output        ddr3_we_n,
   output        ddr3_reset_n,
   output [0:0]  ddr3_ck_p,
   output [0:0]  ddr3_ck_n,
   output [0:0]  ddr3_cke,
   output [0:0]  ddr3_cs_n,
   output [1:0]  ddr3_dm,
   output [0:0]  ddr3_odt,
   // clk & reset
   input wire    CLK12MHZ,
   input wire    sys_clk_i
   );

   wire          clk_ref_i;
   wire          locked;
   wire          init_calib_complete;

   clk_wiz_0 clk_wiz_inst
     (
      .clk_in1(CLK12MHZ),
      .clk_out1(clk_ref_i),
      .locked(locked & init_calib_complete)
      );

   fcpu fcpu_inst
     (.*,
      .sys_clk_i(sys_clk_i),
      .clk_ref_i(clk_ref_i),
      .device_temp_i('b0),
      .init_calib_complete(init_calib_complete),
      .tg_compare_error(),
      .sys_rst_n(locked),
      .ui_clk()
      );
endmodule
