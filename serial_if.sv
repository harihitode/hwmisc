`timescale 1 ns / 1 ps

module serial_interface
  // 100MHz 115200bps
  #(parameter logic [15:0] WTIME = 16'h364)
   (
    input  clk,
    input  uart_txd_in,
    output uart_rxd_out
    );

   logic   rx, sysclk;

   logic   recv_ready, recv_valid;
   logic   send_ready, send_valid;
   logic [7:0] recv_data, send_data;

   // Gen GLOBAL CLK
   IBUFG clkbuf1 (.I(clk), .O(sysclk));

   // DFF for avoid meta-stable
   logic       rxd = 'b1;
   IBUF rxbuf (.I(uart_txd_in), .O(rx));
   always_ff @(posedge sysclk) rxd <= rx;

   uart_receiver
     #(.WTIME(WTIME))
   receiver
     (.clk(sysclk),
      .nrst('b1),
      .valid(recv_valid),
      .data(recv_data),
      .ready(recv_ready),
      .rx(rxd));

   fifo
     #(.FIFO_DEPTH_W(3), .DATA_W(8))
   serial_fifo
     (.clk(sysclk),
      .nrst('b1),
      .a_data(recv_data),
      .a_valid(recv_valid),
      .a_ready(recv_ready),
      .b_data(send_data),
      .b_valid(send_valid),
      .b_ready(send_ready));

   uart_transmitter
     #(.WTIME(WTIME))
   transmitter
     (.clk(sysclk),
      .nrst('b1),
      .valid(send_valid),
      .data(send_data),
      .ready(send_ready),
      .tx(uart_rxd_out));

endmodule
