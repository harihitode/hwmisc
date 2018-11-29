`timescale 1 ns / 1 ps

module serial_tb ();

   logic clk = 0;
   initial forever #5 clk <= ~clk;
   logic nrst = 'b1;

   wire  uart_txd_in;
   wire  uart_rxd_out;

   uart_transmitter
     #(.WTIME(16'h364))
   pc_side
     (
      .*,
      .valid('b1),
      .data(8'haa),
      .ready(),
      .tx(uart_txd_in)
      );

   serial_top dev_side (
                        .*
                        );

endmodule
