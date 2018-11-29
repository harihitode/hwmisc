`timescale 1 ns / 1 ps

module serial_top
  (
   input logic clk,
   // serial ports
   input       uart_txd_in,
   output      uart_rxd_out
   );

   // internal signals
   logic       uart_txd_in_d, sysclk;

   // Gen GLOBAL CLK
   IBUFG clk_buf (.I(clk), .O(sysclk));

   // DFF for avoid meta-stable
   logic       uart_txd_in_dd = 'b1;
   IBUF rcv_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   always_ff @(posedge sysclk) uart_txd_in_dd <= uart_txd_in_d;

   localparam I_BYTES = 1;
   localparam O_BYTES = 1;

   wire [I_BYTES*8-1:0] i_data;
   wire                 i_valid;
   wire                 i_ready;

   wire [O_BYTES*8-1:0] o_data;
   wire                 o_valid;
   wire                 o_ready;

   assign i_data = o_data;
   assign i_valid = o_valid;
   assign o_ready = i_ready;

   serial_interface
     #(.I_BYTES(I_BYTES),
       .O_BYTES(O_BYTES))
   serial_if_inst
     (
      .clk(sysclk),
      .uart_txd_in(uart_txd_in_dd),
      .uart_rxd_out(uart_rxd_out),
      .nrst('b1),
      .*
      );
endmodule
