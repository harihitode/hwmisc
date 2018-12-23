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

   logic [7:0] send_data = 'b0;
   logic       send_valid = 'b0;
   wire        send_ready;

   wire [7:0]  recv_data;
   wire        recv_valid;
   logic       recv_ready = 'b1;

   wire [7:0]  io_wdata;
   wire        io_wvalid;
   wire        io_wready;

   wire [7:0]  io_rdata;
   wire        io_rvalid;
   wire        io_rready;

   // cram addr ports
   wire [3:0]  s_cram_arid;
   wire [31:0] s_cram_araddr;
   wire [7:0]  s_cram_arlen;
   wire [2:0]  s_cram_arsize;
   wire [1:0]  s_cram_arburst;
   wire [0:0]  s_cram_arlock;
   wire [3:0]  s_cram_arcache;
   wire [2:0]  s_cram_arprot;
   wire [3:0]  s_cram_arqos;
   wire        s_cram_arvalid;
   wire        s_cram_arready;

   // cram data ports
   wire        s_cram_rready;
   wire [3:0]  s_cram_rid;
   wire [31:0] s_cram_rdata;
   wire [1:0]  s_cram_rresp;
   wire        s_cram_rlast;
   wire        s_cram_rvalid;

   fcpu fcpu_inst
     (
      .*,
      // {
      // write address
      .io_awid(),
      .io_awaddr(),
      .io_awlen(),
      .io_awsize(),
      .io_awburst(),
      .io_awlock(),
      .io_awcache(),
      .io_awprot(),
      .io_awqos(),
      .io_awvalid(),
      .io_awready(1'b1),
      // write data
      .io_wdata(io_wdata),
      .io_wstrb(),
      .io_wlast(),
      .io_wvalid(io_wvalid),
      .io_wready(io_wready),
      // response
      .io_bready(),
      .io_bid('b0),
      .io_bresp('b0),
      .io_bvalid('b0),
      // read address
      .io_arid(),
      .io_araddr(),
      .io_arlen(),
      .io_arsize(),
      .io_arburst(),
      .io_arlock(),
      .io_arcache(),
      .io_arprot(),
      .io_arqos(),
      .io_arvalid(),
      .io_arready(1'b1),
      // read data
      .io_rready(io_rready),
      .io_rid('b0),
      .io_rdata(io_rdata),
      .io_rresp('b0),
      .io_rlast('b1),
      .io_rvalid(io_rvalid),
      // }

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
     #(.WTIME(16'h0030))
   serial_device_side
     (
      .clk(clk),
      .uart_txd_in(rs_tx_in),
      .uart_rxd_out(rs_rx_out),

      .i_data(io_wdata),
      .i_valid(io_wvalid),
      .i_ready(io_wready),

      .o_data(io_rdata),
      .o_valid(io_rvalid),
      .o_ready(io_rready),

      .nrst(nrst)
      );

   serial_interface
     #(.WTIME(16'h0030))
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

   blk_mem_gen_0 cram_inst
     (
      .s_aclk(clk),
      .s_axi_arid(s_cram_arid),
      .s_axi_araddr(s_cram_araddr),
      .s_axi_arlen(s_cram_arlen),
      .s_axi_arsize(s_cram_arsize),
      .s_axi_arburst(s_cram_arburst),
      .s_axi_arvalid(s_cram_arvalid),
      .s_axi_arready(s_cram_arready),
      .s_axi_rid(s_cram_rid),
      .s_axi_rdata(s_cram_rdata),
      .s_axi_rresp(s_cram_rresp),
      .s_axi_rlast(s_cram_rlast),
      .s_axi_rvalid(s_cram_rvalid),
      .s_axi_rready(s_cram_rready),
      .s_aresetn('b1),
      .s_axi_awid('b0),
      .s_axi_awaddr('b0),
      .s_axi_awlen('b0),
      .s_axi_awsize('b0),
      .s_axi_awburst('b1),
      .s_axi_awvalid('b0),
      .s_axi_awready(),
      .s_axi_wdata('b0),
      .s_axi_wstrb('b0),
      .s_axi_wlast('b0),
      .s_axi_wvalid('b0),
      .s_axi_wready(),
      .s_axi_bid(),
      .s_axi_bresp(),
      .s_axi_bvalid(),
      .s_axi_bready('b1),
      .rsta_busy(),
      .rstb_busy()
      );

   initial begin
      #5000 nrst <= 'b1;
      #7000 nrst <= 'b0;
      #5000 nrst <= 'b1;
      #15000;
      send_valid <= 'b1;
      send_data <='h11;
      @(posedge clk);
      send_valid <= 'b0;
      #15000;
      send_valid <= 'b1;
      send_data <='h22;
      @(posedge clk);
      send_valid <= 'b0;
      #15000;
      send_valid <= 'b1;
      send_data <='h33;
      @(posedge clk);
      send_valid <= 'b0;
      #15000;
      send_valid <= 'b1;
      send_data <='h44;
      @(posedge clk);
      send_valid <= 'b0;
      #15000;
      send_valid <= 'b1;
      send_data <='h55;
      @(posedge clk);
      send_valid <= 'b0;
      #15000;
      send_valid <= 'b1;
      send_data <='h66;
      @(posedge clk);
      send_valid <= 'b0;
   end

endmodule
