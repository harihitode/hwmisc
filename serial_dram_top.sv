`timescale 1 ns / 1 ps

module serial_dram_top
  (
   // serial
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
   input              CLK12MHZ, // for reference clock of DRAM interface
   input              CLK100MHZ, // for system clock
   input              ck_rst
   );

   wire               clk;
   wire               sys_clk_i;
   wire               clk_ref_i;
   wire               clk_locked;
   wire               dram_locked;
   wire               sys_rst;
   wire               nrst;

   // reset sygnals
   assign sys_rst = ck_rst & clk_locked;
   assign nrst = sys_rst & dram_locked;

   // debug lights
   always_comb begin
      led[0] <= clk_locked;
      led[1] <= dram_locked;
      led[2] <= sys_rst;
      led[3] <= nrst;
   end

   clk_wiz_0 clk_wiz_inst
     (
      .clk_in1(CLK12MHZ),
      .clk_out1(clk_ref_i),
      .clk_out2(clk),
      .locked(clk_locked)
      );

   // Gen GLOBAL CLK
   IBUFG clk_buf (.I(CLK100MHZ), .O(sys_clk_i));

   wire               uart_txd_in_d, uart_rxd_out_i;

   // DFF for avoid meta-stable
   IBUF txd_in_buf (.I(uart_txd_in), .O(uart_txd_in_d));
   OBUF rxd_out_buf (.I(uart_rxd_out_i), .O(uart_rxd_out));

   wire [I_BYTES*8-1:0] i_data;
   wire                 i_valid;
   wire                 i_ready;

   wire [O_BYTES*8-1:0] o_data;
   wire                 o_valid;
   wire                 o_ready;

   logic [O_BYTES*8-1:0] o_data_l = 'b0;

   // Slave Interface Write Data Ports
   wire [3:0]            s_axi_awid;
   wire [27:0]           s_axi_awaddr;
   wire [7:0]            s_axi_awlen;
   wire [2:0]            s_axi_awsize;
   wire [1:0]            s_axi_awburst;
   wire [0:0]            s_axi_awlock;
   wire [3:0]            s_axi_awcache;
   wire [2:0]            s_axi_awprot;
   wire [3:0]            s_axi_awqos;
   logic                 s_axi_awvalid = 'b0;
   wire                  s_axi_awready;
   // Slave Interface Write Data Ports
   wire [127:0]          s_axi_wdata;
   wire [15:0]           s_axi_wstrb;
   logic                 s_axi_wlast = 'b0;
   logic                 s_axi_wvalid = 'b0;
   wire                  s_axi_wready;
   // Slave Interface Write Response Ports
   logic                 s_axi_bready = 'b0;
   wire [3:0]            s_axi_bid;
   wire [1:0]            s_axi_bresp;
   wire                  s_axi_bvalid;
   // Slave Interface Read Address Ports
   wire [3:0]            s_axi_arid;
   wire [27:0]           s_axi_araddr;
   wire [7:0]            s_axi_arlen;
   wire [2:0]            s_axi_arsize;
   wire [1:0]            s_axi_arburst;
   wire [0:0]            s_axi_arlock;
   wire [3:0]            s_axi_arcache;
   wire [2:0]            s_axi_arprot;
   wire [3:0]            s_axi_arqos;
   logic                 s_axi_arvalid = 'b0;
   wire                  s_axi_arready;
   // Slave Interface Read Data Ports
   logic                 s_axi_rready = 'b0;
   wire [3:0]            s_axi_rid;
   wire [127:0]          s_axi_rdata;
   wire [1:0]            s_axi_rresp;
   wire                  s_axi_rlast;
   wire                  s_axi_rvalid;

   assign s_axi_awid = 'b0;
   assign s_axi_awaddr = {20'd0, sw, 4'b0000}; // 128bit = 16byte alignment
   assign s_axi_awlen = 'b0;
   assign s_axi_awsize = 3'h2;
   assign s_axi_awburst = 2'b1;
   assign s_axi_awlock = 'b0;
   assign s_axi_awcache = 'b0;
   assign s_axi_awprot = 'b0;
   assign s_axi_awqos = 'b0;

   assign s_axi_wdata = {120'd0, o_data_l};
   assign s_axi_wstrb = '1;

   assign s_axi_arid = 'b0;
   assign s_axi_araddr = {20'd0, sw, 4'b0000};
   assign s_axi_arlen = 'b0;
   assign s_axi_arsize = 3'h2;
   assign s_axi_arburst = 2'b1;
   assign s_axi_arlock = 'b0;
   assign s_axi_arcache = 'b0;
   assign s_axi_arprot = 'b0;
   assign s_axi_arqos = 'b0;

   always_ff @(posedge clk) begin
      s_axi_awvalid <= o_valid;
      // latch data from serial
      if (o_valid && o_ready) begin
         o_data_l <= o_data;
      end
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

   always_ff @(posedge clk) begin
      s_axi_arvalid <= btn[0];
      if (s_axi_rvalid) begin
         s_axi_rready <= 'b1;
      end else begin
         s_axi_rready <= 'b0;
      end
   end

   assign i_data = s_axi_rdata[I_BYTES*8-1:0];
   assign i_valid = s_axi_rvalid;
   assign o_ready = s_axi_awready;

   localparam I_BYTES = 1;
   localparam O_BYTES = 1;
   serial_interface
     #(.I_BYTES(I_BYTES),
       .O_BYTES(O_BYTES))
   serial_if_inst
     (
      .clk(clk),
      .uart_txd_in(uart_txd_in_d),
      .uart_rxd_out(uart_rxd_out_i),
      .nrst(nrst),
      .*
      );

   dram_ctrl_wrapper dram_ctrl_inst
     (
      .*,
      .clk(clk),
      .clk_ref_i(clk_ref_i),
      .sys_clk_i(sys_clk_i),
      .locked(dram_locked),
      .nrst(sys_rst)
      );

endmodule
