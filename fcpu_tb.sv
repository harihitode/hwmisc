`timescale 1 ns / 1 ps

module fcpu_tb ();

   logic clk = 0;
   initial forever #5 clk <= ~clk;
   logic nrst = 'b0;

   wire  rs_tx_in;
   wire  rs_rx_out;

   logic [7:0] send_data  = 'hab;
   logic       send_valid = 'b0;
   wire        send_ready;

   wire [7:0]  recv_data;
   wire        recv_valid;
   logic       recv_ready = 'b1;

   fcpu fcpu_inst
     (
      .*
      );

   serial_interface serial_pc_side
     (
      .clk(clk),
      .uart_txd_in(rs_rx_out),
      .uart_rxd_out(rs_tx_in),

      .i_data(send_data),
      .i_valid(send_valid),
      .i_ready(send_ready),

      .o_data(recv_data),
      .o_valid(recv_valid),
      .o_ready(recv_ready),

      .nrst(nrst)
      );

   initial begin
      #50 nrst <= 'b1;
      #100;
      send_valid <= 'b1;
      @(posedge clk);
      send_valid <= 'b0;
   end

endmodule
