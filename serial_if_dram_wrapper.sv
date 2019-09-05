`timescale 1 ns / 1 ps

module serial_dram_wrapper
  (
   // serial
   input              uart_txd_in,
   output             uart_rxd_out,
   // LED
   output logic [3:0] led,
   // Switch
   input logic [3:0]  sw,
   // btn
   input logic [3:0]  btn,
   // DDR
   inout [15:0]       ddr3_dq,
   inout [1:0]        ddr3_dqs_n,
   inout [1:0]        ddr3_dqs_p,
   // Outputs
   output [13:0]      ddr3_addr,
   output [2:0]       ddr3_ba,
   output             ddr3_ras_n,
   output             ddr3_cas_n,
   output             ddr3_we_n,
   output             ddr3_reset_n,
   output [0:0]       ddr3_ck_p,
   output [0:0]       ddr3_ck_n,
   output [0:0]       ddr3_cke,
   output [0:0]       ddr3_cs_n,
   output [1:0]       ddr3_dm,
   output [0:0]       ddr3_odt,
   // clk & reset
   input              CLK12MHZ, // for reference clock of DRAM interface
   input              CLK100MHZ, // for system clock
   input              ck_rst
   );

   wire               sys_clk_i;
   wire               clk_ref_i;
   wire               locked;

   clk_wiz_0 clk_wiz_inst
     (
      .clk_in1(CLK12MHZ),
      .clk_out1(clk_ref_i),
      .locked(locked)
      );
   assign sys_clk_i = CLK100MHZ;

   wire               uart_txd_in_d, uart_rxd_out_i;

   // DFF for avoid meta-stable
   IBUF txd_in_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   OBUF rxd_out_buf (.I(uart_rxd_out_i), .O(uart_rxd_out));

   serial_dram_top serial_top_module
     (
      .*,
      .uart_txd_in(uart_txd_in_d),
      .uart_rxd_out(uart_rxd_out_i),
      .init_calib_complete(),
      .tg_compare_error(),
      .ui_clk(),
      .sys_rst(ck_rst & locked)
      );

endmodule
