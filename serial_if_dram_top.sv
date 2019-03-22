`timescale 1 ns / 1 ps

module serial_top
  (
   // serial ports
   input              uart_txd_in,
   output             uart_rxd_out,
   // LED
   output logic [3:0] led,
   // Switch
   input logic [3:0]  sw,
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
   output             init_calib_complete,
   output             tg_compare_error,
   input              clk_ref_i,
   input              sys_clk_i,
   output             ui_clk,
   input              sys_rst
   );

   wire               sys_rst_n;
   wire               mmcm_locked;
   wire               uart_txd_in_d;
   wire               uart_rxd_out_i;

   assign sys_rst_n = mmcm_locked & sys_rst & init_calib_complete;

   always_comb begin
      led[0] <= sw[0];
      led[1] <= sys_rst_n;
      led[2] <= init_calib_complete;
      led[3] <= btn[3];
   end

   assign tg_compare_error = 'b0;

   // Gen GLOBAL CLK
   // IBUFG clk_buf (.I(sys_clk_i), .O(sysclk));

   // DFF for avoid meta-stable
   logic       uart_txd_in_dd = 'b1;
   OBUF rx_buf (.I(uart_rxd_out_i), .O(uart_rxd_out));
   IBUF rcv_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   always_ff @(posedge ui_clk) uart_txd_in_dd <= uart_txd_in_d;

   localparam I_BYTES = 1;
   localparam O_BYTES = 1;

   wire [I_BYTES*8-1:0] i_data;
   wire                 i_valid;
   wire                 i_ready;

   wire [O_BYTES*8-1:0] o_data;
   wire                 o_valid;
   wire                 o_ready;

   // Slave Interface Write Data Ports
   wire [3:0]           s_axi_awid;
   wire [27:0]          s_axi_awaddr;
   wire [7:0]           s_axi_awlen;
   wire [2:0]           s_axi_awsize;
   wire [1:0]           s_axi_awburst;
   wire [0:0]           s_axi_awlock;
   wire [3:0]           s_axi_awcache;
   wire [2:0]           s_axi_awprot;
   wire [3:0]           s_axi_awqos;
   logic                s_axi_awvalid = 'b0;
   wire                 s_axi_awready;
   // Slave Interface Write Data Ports
   wire [127:0]         s_axi_wdata;
   wire [15:0]          s_axi_wstrb;
   logic                s_axi_wlast = 'b0;
   logic                s_axi_wvalid = 'b0;
   wire                 s_axi_wready;
   // Slave Interface Write Response Ports
   logic                s_axi_bready = 'b0;
   wire [3:0]           s_axi_bid;
   wire [1:0]           s_axi_bresp;
   wire                 s_axi_bvalid;
   // Slave Interface Read Address Ports
   wire [3:0]           s_axi_arid;
   wire [27:0]          s_axi_araddr;
   wire [7:0]           s_axi_arlen;
   wire [2:0]           s_axi_arsize;
   wire [1:0]           s_axi_arburst;
   wire [0:0]           s_axi_arlock;
   wire [3:0]           s_axi_arcache;
   wire [2:0]           s_axi_arprot;
   wire [3:0]           s_axi_arqos;
   logic                s_axi_arvalid = 'b0;
   wire                 s_axi_arready;
   // Slave Interface Read Data Ports
   logic                s_axi_rready = 'b0;
   wire [3:0]           s_axi_rid;
   wire [127:0]         s_axi_rdata;
   wire [1:0]           s_axi_rresp;
   wire                 s_axi_rlast;
   wire                 s_axi_rvalid;

   assign s_axi_awid = 'b0;
   assign s_axi_awaddr = 28'h000_4000;
   assign s_axi_awlen = 'b0;
   assign s_axi_awsize = 3'h2;
   assign s_axi_awburst = 2'b1;
   assign s_axi_awlock = 'b0;
   assign s_axi_awcache = 'b0;
   assign s_axi_awprot = 'b0;
   assign s_axi_awqos = 'b0;

   assign s_axi_wdata = 128'h0067;
   assign s_axi_wstrb = '1;

   assign s_axi_arid = 'b0;
   assign s_axi_araddr = 28'h000_4000;
   assign s_axi_arlen = 'b0;
   assign s_axi_arsize = 3'h2;
   assign s_axi_arburst = 2'b1;
   assign s_axi_arlock = 'b0;
   assign s_axi_arcache = 'b0;
   assign s_axi_arprot = 'b0;
   assign s_axi_arqos = 'b0;

   always_ff @(posedge ui_clk) begin
      s_axi_awvalid <= btn[3];
      if (s_axi_awvalid && s_axi_awready) begin
         s_axi_wvalid <= 'b1;
         s_axi_wlast <= 'b1;
      end else begin
         s_axi_wvalid <= 'b0;
         s_axi_wlast <= 'b0;
      end
      if (s_axi_bvalid) begin
         s_axi_bready <= 'b1;
      end else begin
         s_axi_bready <= 'b0;
      end
   end

   always_ff @(posedge ui_clk) begin
      s_axi_arvalid <= btn[2];
      if (s_axi_rvalid) begin
         s_axi_rready <= 'b1;
      end else begin
         s_axi_rready <= 'b0;
      end
   end

   // assign i_data = o_data[I_BYTES*8-1:0];
   // assign i_valid = o_valid;
   // assign o_ready = i_ready;

   assign i_data = s_axi_rdata[I_BYTES*8-1:0];
   assign i_valid = s_axi_rvalid;
   assign o_ready = s_axi_wready;

   serial_interface
     #(.WTIME(16'h02c1),
       .I_BYTES(I_BYTES),
       .O_BYTES(O_BYTES))
   serial_if_inst
     (
      .clk(ui_clk),
      .uart_txd_in(uart_txd_in_dd),
      .uart_rxd_out(uart_rxd_out_i),
      .nrst(sys_rst_n),
      .*
      );

   mig_7series_0 mem_if_inst
     (
      .*,
      .ui_clk(ui_clk),
      .ui_clk_sync_rst(), // output
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
      .sys_rst(sys_rst) // negative
      );

endmodule
