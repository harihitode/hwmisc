`timescale 1 ns / 1 ps

module fcpu_tb ();

   logic sys_clk = 0;
   initial forever #10 sys_clk <= ~sys_clk;
   logic ref_clk = 0;
   initial forever #5 ref_clk <= ~ref_clk;
   logic nrst = 'b0;

   wire  rs_tx_in;
   wire  rs_rx_out;
   wire  clk;

   logic [7:0] send_data  = 'hab;
   logic       send_valid = 'b0;
   wire        send_ready;

   wire [7:0]  recv_data;
   wire        recv_valid;
   logic       recv_ready = 'b1;

   fcpu
     #(.WTIME(16'h40))
   fcpu_inst
     (
      .*,
      .uart_txd_in(rs_tx_in),
      .uart_rxd_out(rs_rx_out),

      .ddr3_dq(),
      .ddr3_dqs_n(),
      .ddr3_dqs_p(),
      .ddr3_addr(),
      .ddr3_ba(),
      .ddr3_ras_n(),
      .ddr3_cas_n(),
      .ddr3_we_n(),
      .ddr3_reset_n(),
      .ddr3_ck_p(),
      .ddr3_ck_n(),
      .ddr3_cke(),
      .ddr3_cs_n(),
      .ddr3_dm(),
      .ddr3_odt(),

      .sys_clk_i(sys_clk),
      .clk_ref_i(ref_clk),
      .device_temp_i('b0),

      .init_calib_complete(),
      .tg_compare_error(),
      .sys_rst_n(nrst),
      .ui_clk(clk)
      );

   serial_interface
     #(.WTIME(16'h40))
   serial_pc_side
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
