`timescale 1 ns / 1 ps

module serial_interface
  // 100MHz 115200bps
  #(parameter logic [15:0] WTIME = 16'h364,
    parameter I_BYTES = 1,
    parameter O_BYTES = 1)
   (
    input                        clk,
    // serial ports
    input                        uart_txd_in,
    output                       uart_rxd_out,
    //
    input logic [I_BYTES*8-1:0]  i_data,
    input logic                  i_valid,
    output logic                 i_ready,

    output logic [O_BYTES*8-1:0] o_data,
    output logic                 o_valid,
    input logic                  o_ready,

    input logic                  nrst
    );

   logic   recv_ready, recv_valid;
   logic   trns_ready, trns_valid;
   logic [7:0] recv_data, trns_data;

   uart_receiver
     #(.WTIME(WTIME))
   receiver
     (.clk(clk),
      .nrst(nrst),
      .valid(recv_valid),
      .data(recv_data),
      .ready(recv_ready),
      .rx(uart_txd_in));

   fifo
     #(.FIFO_DEPTH_W(3), .DATA_W(8*O_BYTES))
   uarc_rcv_fifo
     (.clk(clk),
      .nrst(nrst),
      .a_data(recv_data),
      .a_valid(recv_valid),
      .a_ready(recv_ready),
      .b_data(o_data),
      .b_valid(o_valid),
      .b_ready(o_ready));

   uart_transmitter
     #(.WTIME(WTIME))
   transmitter
     (.clk(clk),
      .nrst(nrst),
      .valid(trns_valid),
      .data(trns_data),
      .ready(trns_ready),
      .tx(uart_rxd_out));

   fifo
     #(.FIFO_DEPTH_W(3), .DATA_W(8*I_BYTES))
   uarc_trns_fifo
     (.clk(clk),
      .nrst(nrst),
      .a_data(i_data),
      .a_valid(i_valid),
      .a_ready(i_ready),
      .b_data(trns_data),
      .b_valid(trns_valid),
      .b_ready(trns_ready));

endmodule
