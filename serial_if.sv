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

   logic [O_BYTES*8-1:0]         recv_data_buf = '0;
   int                           recv_cnt = 0;
   wire                          recv_fifo_valid;
   logic                         recv_ready, recv_valid;
   logic [7:0]                   recv_data;


   wire [I_BYTES*8-1:0]          trns_data_buf;
   int                           trns_cnt = '0;
   wire                          trns_fifo_ready;
   logic                         trns_ready, trns_valid;
   wire [7:0]                    trns_data;

   generate begin for (genvar i = 0; i < O_BYTES; i++) begin
      always_comb begin
         recv_data_buf[i*8+:8] <= (recv_cnt == i && recv_valid) ? recv_data : recv_data_buf[i*8+:8];
      end
   end end
   endgenerate

   assign recv_fifo_valid = (recv_cnt == O_BYTES-1 && recv_valid) ? 'b1 : 'b0;

   always_ff @(posedge clk) begin
      if (recv_valid && recv_cnt == O_BYTES-1) begin
         recv_cnt <= 0;
      end else if (recv_valid && recv_ready) begin
         recv_cnt <= recv_cnt + 1;
      end
   end

   assign trns_data = trns_data_buf[trns_cnt*8+:8];

   assign trns_fifo_ready = (trns_cnt == I_BYTES-1 && trns_ready) ? 'b1 : 'b0;

   always_ff @(posedge clk) begin
      if (trns_ready && trns_cnt == I_BYTES-1) begin
         trns_cnt <= 0;
      end else if (trns_ready && trns_valid) begin
         trns_cnt <= trns_cnt + 1;
      end
   end

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
      .a_data(recv_data_buf),
      .a_valid(recv_fifo_valid),
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
      .b_data(trns_data_buf),
      .b_valid(trns_valid),
      .b_ready(trns_fifo_ready));

endmodule
