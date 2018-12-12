`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  #(parameter logic [15:0] WTIME = 16'h364)
   (
    // serial
    input         uart_txd_in,
    output        uart_rxd_out,
    // DDR
    inout [15:0]  ddr3_dq,
    inout [1:0]   ddr3_dqs_n,
    inout [1:0]   ddr3_dqs_p,
    // Outputs
    output [13:0] ddr3_addr,
    output [2:0]  ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p,
    output [0:0]  ddr3_ck_n,
    output [0:0]  ddr3_cke,
    output [0:0]  ddr3_cs_n,
    output [1:0]  ddr3_dm,
    output [0:0]  ddr3_odt,
    // clk & reset
    input         sys_clk_i,
    input         clk_ref_i,
    input [11:0]  device_temp_i,

    output        init_calib_complete,
    output        tg_compare_error,
    input         sys_rst_n,
    output        ui_clk
    );

   wire           nrst;
   wire           mmcm_locked;
   wire           ui_clk_i;
   assign tg_compare_error = 'b0;
   assign nrst = sys_rst_n & mmcm_locked;
   assign ui_clk = ui_clk_i;

   // cram addr ports
   wire [3:0]     s_cram_arid;
   wire [31:0]    s_cram_araddr;
   wire [7:0]     s_cram_arlen;
   wire [2:0]     s_cram_arsize;
   wire [1:0]     s_cram_arburst;
   wire [0:0]     s_cram_arlock;
   wire [3:0]     s_cram_arcache;
   wire [2:0]     s_cram_arprot;
   wire [3:0]     s_cram_arqos;
   wire           s_cram_arvalid;
   wire           s_cram_arready;

   // cram data ports
   wire           s_cram_rready;
   wire [3:0]     s_cram_rid;
   wire [31:0]    s_cram_rdata;
   wire [1:0]     s_cram_rresp;
   wire           s_cram_rlast;
   wire           s_cram_rvalid;

   blk_mem_gen_0 cram_inst
     (
      .s_aclk(ui_clk_i),
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

   wire [7:0] io_o_data;
   wire       io_o_valid;
   wire       io_o_ready;

   wire [7:0] io_i_data;
   wire       io_i_valid;
   wire       io_i_ready;

   wire [RSV_ID_W-1:0] mmu_rsv_id;
   wire                mmu_valid;
   wire [DATA_W-1:0]   mmu_data;
   wire [DATA_W-1:0]   mmu_addr;
   wire [INSTR_W-1:0]  mmu_opcode;
   wire                mmu_ready;

   wire [CDB_W-1:0]    mmu_cdb;
   wire                mmu_cdb_valid;
   wire                mmu_cdb_ready;

   // Slave Interface Write Data Ports
   wire [3:0]          s_axi_awid;
   wire [27:0]         s_axi_awaddr;
   wire [7:0]          s_axi_awlen;
   wire [2:0]          s_axi_awsize;
   wire [1:0]          s_axi_awburst;
   wire [0:0]          s_axi_awlock;
   wire [3:0]          s_axi_awcache;
   wire [2:0]          s_axi_awprot;
   wire [3:0]          s_axi_awqos;
   wire                s_axi_awvalid;
   wire                s_axi_awready;
   // Slave Interface Write Data Ports
   wire [127:0]        s_axi_wdata;
   wire [15:0]         s_axi_wstrb;
   wire                s_axi_wlast;
   wire                s_axi_wvalid;
   wire                s_axi_wready;
   // Slave Interface Write Response Ports
   wire                s_axi_bready;
   wire [3:0]          s_axi_bid;
   wire [1:0]          s_axi_bresp;
   wire                s_axi_bvalid;
   // Slave Interface Read Address Ports
   wire [3:0]          s_axi_arid;
   wire [27:0]         s_axi_araddr;
   wire [7:0]          s_axi_arlen;
   wire [2:0]          s_axi_arsize;
   wire [1:0]          s_axi_arburst;
   wire [0:0]          s_axi_arlock;
   wire [3:0]          s_axi_arcache;
   wire [2:0]          s_axi_arprot;
   wire [3:0]          s_axi_arqos;
   wire                s_axi_arvalid;
   wire                s_axi_arready;
   // Slave Interface Read Data Ports
   wire                s_axi_rready;
   wire [3:0]          s_axi_rid;
   wire [127:0]        s_axi_rdata;
   wire [1:0]          s_axi_rresp;
   wire                s_axi_rlast;
   wire                s_axi_rvalid;

   core core_inst
     (
      .*,
      .clk(ui_clk_i)
      );

   memory_management_unit mmu_inst
     (
      .*,
      .clk(ui_clk_i),

      .rsv_id(mmu_rsv_id),
      .valid(mmu_valid),
      .data(mmu_data),
      .address(mmu_addr),
      .opcode(mmu_opcode),
      .ready(mmu_ready),

      .io_o_data(io_o_data),
      .io_o_valid(io_o_valid),
      .io_o_ready(io_o_ready),

      .io_i_data(io_i_data),
      .io_i_valid(io_i_valid),
      .io_i_ready(io_i_ready),

      .o_cdb(mmu_cdb),
      .o_cdb_valid(mmu_cdb_valid),
      .o_cdb_ready(mmu_cdb_ready),

      .nrst(nrst)
      );

   serial_interface
     #(.WTIME(WTIME))
   serial_if_inst
     (
      .clk(ui_clk_i),
      .uart_txd_in(uart_txd_in),
      .uart_rxd_out(uart_rxd_out),

      .i_data(io_o_data),
      .i_valid(io_o_valid),
      .i_ready(io_o_ready),

      .o_data(io_i_data),
      .o_valid(io_i_valid),
      .o_ready(io_i_ready),

      .nrst(nrst)
      );

   mig_7series_0 mem_if_inst
     (
      .*,
      .ui_clk(ui_clk_i),
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

      .sys_rst(sys_rst_n) // negative
      );

endmodule
