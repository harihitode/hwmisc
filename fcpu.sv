`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
   // clk & reset
   input logic         sys_clk_i,
   input logic         clk_ref_i,
   input logic [11:0]  device_temp_i,
   // CRAM {
   // cram addr ports
   output logic [3:0]  s_cram_arid,
   output logic [31:0] s_cram_araddr,
   output logic [7:0]  s_cram_arlen,
   output logic [2:0]  s_cram_arsize,
   output logic [1:0]  s_cram_arburst,
   output logic [0:0]  s_cram_arlock,
   output logic [3:0]  s_cram_arcache,
   output logic [2:0]  s_cram_arprot,
   output logic [3:0]  s_cram_arqos,
   output logic        s_cram_arvalid,
   input logic         s_cram_arready,
   // cram data ports
   output logic        s_cram_rready,
   input logic [3:0]   s_cram_rid,
   input logic [31:0]  s_cram_rdata,
   input logic [1:0]   s_cram_rresp,
   input logic         s_cram_rlast,
   input logic         s_cram_rvalid,
   // }
   // DDR {
   inout logic [15:0]  ddr3_dq,
   inout logic [1:0]   ddr3_dqs_n,
   inout logic [1:0]   ddr3_dqs_p,
   output logic [13:0] ddr3_addr,
   output logic [2:0]  ddr3_ba,
   output logic        ddr3_ras_n,
   output logic        ddr3_cas_n,
   output logic        ddr3_we_n,
   output logic        ddr3_reset_n,
   output logic [0:0]  ddr3_ck_p,
   output logic [0:0]  ddr3_ck_n,
   output logic [0:0]  ddr3_cke,
   output logic [0:0]  ddr3_cs_n,
   output logic [1:0]  ddr3_dm,
   output logic [0:0]  ddr3_odt,
   // }
   // I/O {
   // Slave Interface Write Address Ports
   output logic [3:0]  io_awid,
   output logic [27:0] io_awaddr,
   output logic [7:0]  io_awlen,
   output logic [2:0]  io_awsize,
   output logic [1:0]  io_awburst,
   output logic [0:0]  io_awlock,
   output logic [3:0]  io_awcache,
   output logic [2:0]  io_awprot,
   output logic [3:0]  io_awqos,
   output logic        io_awvalid,
   input logic         io_awready,
   // Slave Interface Write Data Ports
   output logic [7:0]  io_wdata,
   output logic [15:0] io_wstrb,
   output logic        io_wlast,
   output logic        io_wvalid,
   input logic         io_wready,
   // Slave Interface Write Response Ports
   output logic        io_bready,
   input logic [3:0]   io_bid,
   input logic [1:0]   io_bresp,
   input logic         io_bvalid,
   // Slave Interface Read Address Ports
   output logic [3:0]  io_arid,
   output logic [27:0] io_araddr,
   output logic [7:0]  io_arlen,
   output logic [2:0]  io_arsize,
   output logic [1:0]  io_arburst,
   output logic [0:0]  io_arlock,
   output logic [3:0]  io_arcache,
   output logic [2:0]  io_arprot,
   output logic [3:0]  io_arqos,
   output logic        io_arvalid,
   input logic         io_arready,
   // Slave Interface Read Data Ports
   output logic        io_rready,
   input logic [3:0]   io_rid,
   input logic [7:0]   io_rdata,
   input logic [1:0]   io_rresp,
   input logic         io_rlast,
   input logic         io_rvalid,
   // }
   output logic        init_calib_complete,
   output logic        tg_compare_error,
   input logic         sys_rst_n,
   output logic        ui_clk
   );

   wire                nrst;
   wire                mmcm_locked;
   wire                ui_clk_i;
   assign tg_compare_error = 'b0;
   assign nrst = sys_rst_n & mmcm_locked;
   assign ui_clk = ui_clk_i;

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
      .o_cdb(mmu_cdb),
      .o_cdb_valid(mmu_cdb_valid),
      .o_cdb_ready(mmu_cdb_ready),

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
