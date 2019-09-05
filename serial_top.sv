`timescale 1 ns / 1 ps

module serial_top
  (
   input logic CLK100MHZ,
   // serial ports
   input       uart_txd_in,
   output      uart_rxd_out
   );

   // internal signals
   logic       uart_txd_in_d, uart_rxd_out_i, sysclk;

   // Gen GLOBAL CLK
   IBUFG clk_buf (.I(CLK100MHZ), .O(sysclk));

   // DFF for avoid meta-stable
   IBUF txd_in_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   OBUF rxd_out_buf (.I(uart_rxd_out_i), .O(uart_rxd_out));

   localparam I_BYTES = 1;
   localparam O_BYTES = 1;

   wire [I_BYTES*8-1:0] i_data;
   wire                 i_valid;
   wire                 i_ready;

   wire [O_BYTES*8-1:0] o_data;
   wire                 o_valid;
   wire                 o_ready;

   assign i_data = o_data[I_BYTES*8-1:0];
   assign i_valid = o_valid;
   assign o_ready = i_ready;

   serial_interface
     #(.I_BYTES(I_BYTES),
       .O_BYTES(O_BYTES))
   serial_if_inst
     (
      .clk(sysclk),
      .uart_txd_in(uart_txd_in_d),
      .uart_rxd_out(uart_rxd_out_i),
      .nrst('b1),
      .*
      );
endmodule
