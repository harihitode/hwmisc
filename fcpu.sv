`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
   // clk & reset
   input  clk,
   input  rs_tx_in,
   output rs_rx_out,
   input  nrst
   );

   logic [2**CRAM_ADDR_W-1:0][DATA_W-1:0] cram = '0;
   wire [CRAM_ADDR_W-1:0]                 cram_addr;
   logic [DATA_W-1:0]                     cram_data = '0;

   always_ff @(posedge clk) begin
      cram_data <= cram[$unsigned(cram_addr)];
   end

   initial begin
      cram[0] <= {I_INPUT, 5'h01, 21'h4};
      cram[1] <= {I_OUTPUT, 5'h01, 21'h4};
      // cram[0] <= {I_SETI2, 5'h01, 21'h4};
      // cram[1] <= {I_SETI2, 5'h02, 21'h4};
      // cram[2] <= {I_SETI2, 5'h03, 21'h777};
      // cram[3] <= {I_SETI2, 5'h04, 21'h999};
      // cram[4] <= {I_STORER, 5'h03, 5'h02, 5'h01, 11'h0};
      // cram[5] <= {I_STORER, 5'h04, 5'h02, 5'h01, 11'h0};
      // cram[6] <= {I_LOADR , 5'h05, 5'h02, 5'h01, 11'h0};
   end

   wire [7:0] io_o_data;
   wire       io_o_valid;
   wire       io_o_ready;

   wire [7:0] io_i_data;
   wire       io_i_valid;
   wire       io_i_ready;

   core core_inst
     (
      .*
      );

   serial_interface serial_if_inst
     (
      .clk(clk),
      .uart_txd_in(rs_tx_in),
      .uart_rxd_out(rs_rx_out),

      .i_data(io_o_data),
      .i_valid(io_o_valid),
      .i_ready(io_o_ready),

      .o_data(io_i_data),
      .o_valid(io_i_valid),
      .o_ready(io_i_ready),

      .nrst(nrst)
      );

endmodule
