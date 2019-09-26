`timescale 1 ns / 1 ps

module dram_ctrl_wrapper
  (
   // clocks
   input          clk,
   input          clk_ref_i,
   input          sys_clk_i,

   // DDR
   inout [15:0]   ddr3_dq,
   inout [1:0]    ddr3_dqs_n,
   inout [1:0]    ddr3_dqs_p,
   output [13:0]  ddr3_addr,
   output [2:0]   ddr3_ba,
   output         ddr3_ras_n,
   output         ddr3_cas_n,
   output         ddr3_we_n,
   output         ddr3_reset_n,
   output [0:0]   ddr3_ck_p,
   output [0:0]   ddr3_ck_n,
   output [0:0]   ddr3_cke,
   output [0:0]   ddr3_cs_n,
   output [1:0]   ddr3_dm,
   output [0:0]   ddr3_odt,

   // AXI
   //// Slave Interface Write Address Ports
   input [3:0]    s_axi_awid,
   input [27:0]   s_axi_awaddr,
   input [7:0]    s_axi_awlen,
   input [2:0]    s_axi_awsize,
   input [1:0]    s_axi_awburst,
   input [0:0]    s_axi_awlock,
   input [3:0]    s_axi_awcache,
   input [2:0]    s_axi_awprot,
   input [3:0]    s_axi_awqos,
   input          s_axi_awvalid,
   output         s_axi_awready,
   //// Slave Interface Write Data Ports
   input [127:0]  s_axi_wdata,
   input [15:0]   s_axi_wstrb,
   input          s_axi_wlast,
   input          s_axi_wvalid,
   output         s_axi_wready,
   //// Slave Interface Write Response Ports
   input          s_axi_bready,
   output [3:0]   s_axi_bid,
   output [1:0]   s_axi_bresp,
   output         s_axi_bvalid,
   //// Slave Interface Read Address Ports
   input [3:0]    s_axi_arid,
   input [27:0]   s_axi_araddr,
   input [7:0]    s_axi_arlen,
   input [2:0]    s_axi_arsize,
   input [1:0]    s_axi_arburst,
   input [0:0]    s_axi_arlock,
   input [3:0]    s_axi_arcache,
   input [2:0]    s_axi_arprot,
   input [3:0]    s_axi_arqos,
   input          s_axi_arvalid,
   output         s_axi_arready,
   //// Slave Interface Read Data Ports
   input          s_axi_rready,
   output [3:0]   s_axi_rid,
   output [127:0] s_axi_rdata,
   output [1:0]   s_axi_rresp,
   output         s_axi_rlast,
   output         s_axi_rvalid,

   output         locked,
   input          nrst
   );

   wire           ui_clk;
   wire           mmcm_locked;
   wire           init_calib_complete;

   wire           locked_i_f;
   wire           locked_i_s;

   assign locked_i_f = mmcm_locked & init_calib_complete;

   (* ASYNC_REG="TRUE" *)
   FDRSE first_locked_l (
                         .Q(locked_i_s), // Data output
                         .C(clk),        // Clock input
                         .CE(1'b1),      // Clock enable input
                         .D(locked_i_f), // Data input
                         .R(1'b0),       // Synchronous reset input
                         .S(1'b0)        // Synchronous set input
                         );

   FDRSE second_locked_l (
                          .Q(locked),     // Data output
                          .C(clk),        // Clock input
                          .CE(1'b1),      // Clock enable input
                          .D(locked_i_s), // Data input
                          .R(1'b0),       // Synchronous reset input
                          .S(1'b0)        // Synchronous set input
                          );

   // Slave Interface Write Address Ports
   wire [3:0]     m_axi_awid;
   wire [27:0]    m_axi_awaddr;
   wire [7:0]     m_axi_awlen;
   wire [2:0]     m_axi_awsize;
   wire [1:0]     m_axi_awburst;
   wire [0:0]     m_axi_awlock;
   wire [3:0]     m_axi_awcache;
   wire [2:0]     m_axi_awprot;
   wire [3:0]     m_axi_awqos;
   wire           m_axi_awvalid;
   wire           m_axi_awready;
   // Slave Interface Write Data Ports
   wire [127:0]   m_axi_wdata;
   wire [15:0]    m_axi_wstrb;
   wire           m_axi_wlast;
   wire           m_axi_wvalid;
   wire           m_axi_wready;
   // Slave Interface Write Response Ports
   wire           m_axi_bready;
   wire [3:0]     m_axi_bid;
   wire [1:0]     m_axi_bresp;
   wire           m_axi_bvalid;
   // Slave Interface Read Address Ports
   wire [3:0]     m_axi_arid;
   wire [27:0]    m_axi_araddr;
   wire [7:0]     m_axi_arlen;
   wire [2:0]     m_axi_arsize;
   wire [1:0]     m_axi_arburst;
   wire [0:0]     m_axi_arlock;
   wire [3:0]     m_axi_arcache;
   wire [2:0]     m_axi_arprot;
   wire [3:0]     m_axi_arqos;
   wire           m_axi_arvalid;
   wire           m_axi_arready;
   // Slave Interface Read Data Ports
   wire           m_axi_rready;
   wire [3:0]     m_axi_rid;
   wire [127:0]   m_axi_rdata;
   wire [1:0]     m_axi_rresp;
   wire           m_axi_rlast;
   wire           m_axi_rvalid;

   axi_clock_converter_0 axi_clock_converter_inst
     (
      .*,
      .s_axi_aclk(clk),
      .s_axi_arregion('b0),
      .s_axi_awregion('b0),
      .s_axi_aresetn(mmcm_locked & init_calib_complete),
      .m_axi_aclk(ui_clk),
      .m_axi_arregion(),
      .m_axi_awregion(),
      .m_axi_aresetn(nrst)
      );

   mig_7series_0 mem_if_inst
     (
      .*,
      .s_axi_awid(m_axi_awid),
      .s_axi_awaddr(m_axi_awaddr),
      .s_axi_awlen(m_axi_awlen),
      .s_axi_awsize(m_axi_awsize),
      .s_axi_awburst(m_axi_awburst),
      .s_axi_awlock(m_axi_awlock),
      .s_axi_awcache(m_axi_awcache),
      .s_axi_awprot(m_axi_awprot),
      .s_axi_awqos(m_axi_awqos),
      .s_axi_awvalid(m_axi_awvalid),
      .s_axi_awready(m_axi_awready),

      .s_axi_wdata(m_axi_wdata),
      .s_axi_wstrb(m_axi_wstrb),
      .s_axi_wlast(m_axi_wlast),
      .s_axi_wvalid(m_axi_wvalid),
      .s_axi_wready(m_axi_wready),

      .s_axi_bready(m_axi_bready),
      .s_axi_bid(m_axi_bid),
      .s_axi_bresp(m_axi_bresp),
      .s_axi_bvalid(m_axi_bvalid),

      .s_axi_arid(m_axi_arid),
      .s_axi_araddr(m_axi_araddr),
      .s_axi_arlen(m_axi_arlen),
      .s_axi_arsize(m_axi_arsize),
      .s_axi_arburst(m_axi_arburst),
      .s_axi_arlock(m_axi_arlock),
      .s_axi_arcache(m_axi_arcache),
      .s_axi_arprot(m_axi_arprot),
      .s_axi_arqos(m_axi_arqos),
      .s_axi_arvalid(m_axi_arvalid),
      .s_axi_arready(m_axi_arready),

      .s_axi_rready(m_axi_rready),
      .s_axi_rid(m_axi_rid),
      .s_axi_rdata(m_axi_rdata),
      .s_axi_rresp(m_axi_rresp),
      .s_axi_rlast(m_axi_rlast),
      .s_axi_rvalid(m_axi_rvalid),

      .ui_clk(ui_clk),
      .ui_clk_sync_rst(), // output
      .mmcm_locked(mmcm_locked),
      .init_calib_complete(init_calib_complete),
      .aresetn('b1),
      .app_sr_req('b0),
      .app_ref_req('b0),
      .app_zq_req('b0),
      .app_sr_active(),
      .app_ref_ack(),
      .app_zq_ack(),
      .device_temp(),
      .device_temp_i(12'b0),
      .sys_rst(nrst) // negative
      );

endmodule
