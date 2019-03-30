`timescale 1 ns / 1 ps
// `include "fcpu_definitions.svh"
// import fcpu_pkg::*;

module fcpu_tb ();

   logic clk = 0;
   initial forever #10 clk <= ~clk;
   logic nrst = 'b0;

   wire  rs_tx_in;
   wire  rs_rx_out;

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

   // Slave Interface Write Data Ports
   wire [3:0]  s_axi_awid;
   wire [27:0] s_axi_awaddr;
   wire [7:0]  s_axi_awlen;
   wire [2:0]  s_axi_awsize;
   wire [1:0]  s_axi_awburst;
   wire [0:0]  s_axi_awlock;
   wire [3:0]  s_axi_awcache;
   wire [2:0]  s_axi_awprot;
   wire [3:0]  s_axi_awqos;
   wire        s_axi_awvalid;
   logic       s_axi_awready = 'b1;
   // Slave Interface Write Data Ports
   wire [31:0] s_axi_wdata;
   wire [3:0]  s_axi_wstrb;
   wire        s_axi_wlast;
   wire        s_axi_wvalid;
   logic       s_axi_wready = 'b1;
   // Slave Interface Write Response Ports
   wire        s_axi_bready;
   logic [3:0] s_axi_bid = 'b0;
   logic [1:0] s_axi_bresp = 'b0;
   logic       s_axi_bvalid = 'b1;
   // Slave Interface Read Address Ports
   wire [3:0]  s_axi_arid;
   wire [27:0] s_axi_araddr;
   wire [7:0]  s_axi_arlen;
   wire [2:0]  s_axi_arsize;
   wire [1:0]  s_axi_arburst;
   wire [0:0]  s_axi_arlock;
   wire [3:0]  s_axi_arcache;
   wire [2:0]  s_axi_arprot;
   wire [3:0]  s_axi_arqos;
   wire        s_axi_arvalid;
   logic       s_axi_arready = 'b1;
   // Slave Interface Read Data Ports
   wire        s_axi_rready;
   logic [3:0] s_axi_rid = 'b0;
   logic [31:0] s_axi_rdata = 'b0;
   logic [1:0]  s_axi_rresp = 'b0;
   logic        s_axi_rlast = 'b1;
   logic        s_axi_rvalid = 'b0;

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
      .clk(clk),
      .sys_rst_n(nrst),
      .halt()
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
      .s_aresetn(nrst),
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

   global_mem gmem_inst
     (
      .m0_araddr(s_axi_araddr),
      .m0_arlen(s_axi_arlen),
      .m0_arvalid(s_axi_arvalid),
      .m0_arready(s_axi_arready),
      .m0_arid(s_axi_arid),

      .m0_rdata(s_axi_rdata),
      .m0_rlast(s_axi_rlast),
      .m0_rvalid(s_axi_rvalid),
      .m0_rready(s_axi_rready),
      .m0_rid(s_axi_rid),

      .m0_awaddr(s_axi_awaddr),
      .m0_awlen(s_axi_awlen),
      .m0_awvalid(s_axi_awvalid),
      .m0_awready(s_axi_awready),
      .m0_awid(s_axi_awid),

      .m0_wdata(s_axi_wdata),
      .m0_wstrb(s_axi_wstrb),
      .m0_wlast(s_axi_wlast),
      .m0_wvalid(s_axi_wvalid),
      .m0_wready(s_axi_wready),

      .m0_bvalid(s_axi_bvalid),
      .m0_bready(s_axi_bready),
      .m0_bid(s_axi_bid),

      .clk(clk),
      .nrst(nrst)
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
