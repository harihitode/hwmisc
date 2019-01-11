`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu_top
  (
   // serial
   input              uart_txd_in,
   output             uart_rxd_out,
   // LED
   output logic [3:0] led,
   // Switch
   input              sw,
   // btn
   input logic [3:0]  btn,
   // DDR
   inout [15:0]       ddr3_dq,
   inout [1:0]        ddr3_dqs_n,
   inout [1:0]        ddr3_dqs_p,
   // Outputs
   output [13:0]      ddr3_addr,
   output [2:0]       ddr3_ba,
   output             ddr3_ras_n,
   output             ddr3_cas_n,
   output             ddr3_we_n,
   output             ddr3_reset_n,
   output [0:0]       ddr3_ck_p,
   output [0:0]       ddr3_ck_n,
   output [0:0]       ddr3_cke,
   output [0:0]       ddr3_cs_n,
   output [1:0]       ddr3_dm,
   output [0:0]       ddr3_odt,
   // clk & reset
   input              CLK12MHZ,
   input              sys_clk_i,
   input              ck_rst
   );

   wire             clk_ref_i;
   wire             locked;
   wire             init_calib_complete;
   wire             uart_txd_in_d;
   wire             uart_rxd_out_i;
   wire             sys_rst_n;
   wire             ui_clk;

   wire [7:0]       io_wdata;
   wire             io_wvalid;
   wire             io_wready;

   wire [7:0]       io_rdata;
   wire             io_rvalid;
   wire             io_rready;

   logic [7:0]      io_wdata_i = 'b0;
   logic            io_wvalid_i = 'b0;

   // cram addr ports
   wire [3:0]       s_cram_arid;
   wire [31:0]      s_cram_araddr;
   wire [7:0]       s_cram_arlen;
   wire [2:0]       s_cram_arsize;
   wire [1:0]       s_cram_arburst;
   wire [0:0]       s_cram_arlock;
   wire [3:0]       s_cram_arcache;
   wire [2:0]       s_cram_arprot;
   wire [3:0]       s_cram_arqos;
   wire             s_cram_arvalid;
   wire             s_cram_arready;

   // cram data ports
   wire [3:0]       s_cram_rid;
   wire [31:0]      s_cram_rdata;
   wire [1:0]       s_cram_rresp;
   wire             s_cram_rlast;
   wire             s_cram_rvalid;
   wire             s_cram_rready;

   // Slave Interface Write Data Ports
   wire [3:0]       s_axi_awid;
   wire [27:0]      s_axi_awaddr;
   wire [7:0]       s_axi_awlen;
   wire [2:0]       s_axi_awsize;
   wire [1:0]       s_axi_awburst;
   wire [0:0]       s_axi_awlock;
   wire [3:0]       s_axi_awcache;
   wire [2:0]       s_axi_awprot;
   wire [3:0]       s_axi_awqos;
   wire             s_axi_awvalid;
   wire             s_axi_awready;
   // Slave Interface Write Data Ports
   wire [127:0]     s_axi_wdata;
   wire [15:0]      s_axi_wstrb;
   wire             s_axi_wlast;
   wire             s_axi_wvalid;
   wire             s_axi_wready;
   // Slave Interface Write Response Ports
   wire             s_axi_bready;
   wire [3:0]       s_axi_bid;
   wire [1:0]       s_axi_bresp;
   wire             s_axi_bvalid;
   // Slave Interface Read Address Ports
   wire [3:0]       s_axi_arid;
   wire [27:0]      s_axi_araddr;
   wire [7:0]       s_axi_arlen;
   wire [2:0]       s_axi_arsize;
   wire [1:0]       s_axi_arburst;
   wire [0:0]       s_axi_arlock;
   wire [3:0]       s_axi_arcache;
   wire [2:0]       s_axi_arprot;
   wire [3:0]       s_axi_arqos;
   wire             s_axi_arvalid;
   wire             s_axi_arready;
   // Slave Interface Read Data Ports
   wire             s_axi_rready;
   wire [3:0]       s_axi_rid;
   wire [127:0]     s_axi_rdata;
   wire [1:0]       s_axi_rresp;
   wire             s_axi_rlast;
   wire             s_axi_rvalid;

   wire             mmcm_locked;

   always_ff @(posedge ui_clk) begin
      if (btn[0]) begin
         io_wvalid_i <= 1'b1;
         io_wdata_i <= 8'h60;
      end else if (s_cram_araddr == 32'h0000_0018) begin
         io_wvalid_i <= 1'b1;
         io_wdata_i <= 8'h70;
      end else begin
         io_wvalid_i <= io_wvalid;
         io_wdata_i <= io_wdata;
      end
   end

   always_comb begin
      led[0] <= sw;
      led[1] <= sys_rst_n;
      led[2] <= init_calib_complete;
      led[3] <= 1'b1;
   end

   assign sys_rst_n = locked & mmcm_locked & ck_rst;

   IBUF tx_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   OBUF rx_buf (.I(uart_rxd_out_i), .O(uart_rxd_out));

   clk_wiz_0 clk_wiz_inst
     (
      .clk_in1(CLK12MHZ),
      .clk_out1(clk_ref_i),
      .locked(locked)
      );

   fcpu fcpu_inst
     (.*,
      .clk(ui_clk),
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
      .sys_rst_n(sys_rst_n)
      );

   serial_interface
     #(.WTIME(16'h02c1))
   serial_if_inst
     (
      .clk(ui_clk),
      .uart_txd_in(uart_txd_in_d),
      .uart_rxd_out(uart_rxd_out_i),

      .i_data(io_wdata_i),
      .i_valid(io_wvalid_i),
      .i_ready(io_wready),

      .o_data(io_rdata),
      .o_valid(io_rvalid),
      .o_ready(io_rready),

      .nrst(sys_rst_n)
      );

   blk_mem_gen_0 cram_inst
     (
      .s_aclk(ui_clk),
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

   mig_7series_0 mem_if_inst
     (
      .*,
      .ui_clk(ui_clk),
      .ui_clk_sync_rst(),
      .mmcm_locked(mmcm_locked),
      .aresetn('b1),
      .app_sr_req('b0),
      .app_ref_req('b0),
      .app_zq_req('b0),
      .app_sr_active(),
      .app_ref_ack(),
      .app_zq_ack(),
      .device_temp(),
      .device_temp_i(12'b0),
      .sys_rst(ck_rst) // negative
      );

endmodule
