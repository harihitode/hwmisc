`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
   // clk & reset
   input logic          clk,
   // CRAM {
   // cram addr ports
   output logic [3:0]   s_cram_arid,
   output logic [31:0]  s_cram_araddr,
   output logic [7:0]   s_cram_arlen,
   output logic [2:0]   s_cram_arsize,
   output logic [1:0]   s_cram_arburst,
   output logic [0:0]   s_cram_arlock,
   output logic [3:0]   s_cram_arcache,
   output logic [2:0]   s_cram_arprot,
   output logic [3:0]   s_cram_arqos,
   output logic         s_cram_arvalid,
   input logic          s_cram_arready,
   // cram data ports
   output logic         s_cram_rready,
   input logic [3:0]    s_cram_rid,
   input logic [31:0]   s_cram_rdata,
   input logic [1:0]    s_cram_rresp,
   input logic          s_cram_rlast,
   input logic          s_cram_rvalid,
   // }
   // DDR {
   // Slave Interface Write Data Ports
   output logic [3:0]   s_axi_awid,
   output logic [27:0]  s_axi_awaddr,
   output logic [7:0]   s_axi_awlen,
   output logic [2:0]   s_axi_awsize,
   output logic [1:0]   s_axi_awburst,
   output logic [0:0]   s_axi_awlock,
   output logic [3:0]   s_axi_awcache,
   output logic [2:0]   s_axi_awprot,
   output logic [3:0]   s_axi_awqos,
   output logic         s_axi_awvalid,
   input logic          s_axi_awready,
   // Slave Interface Write Data Ports
   output logic [127:0] s_axi_wdata,
   output logic [15:0]  s_axi_wstrb,
   output logic         s_axi_wlast,
   output logic         s_axi_wvalid,
   input logic          s_axi_wready,
   // Slave Interface Write Response Ports
   output logic         s_axi_bready,
   input logic [3:0]    s_axi_bid,
   input logic [1:0]    s_axi_bresp,
   input logic          s_axi_bvalid,
   // Slave Interface Read Address Ports
   output logic [3:0]   s_axi_arid,
   output logic [27:0]  s_axi_araddr,
   output logic [7:0]   s_axi_arlen,
   output logic [2:0]   s_axi_arsize,
   output logic [1:0]   s_axi_arburst,
   output logic [0:0]   s_axi_arlock,
   output logic [3:0]   s_axi_arcache,
   output logic [2:0]   s_axi_arprot,
   output logic [3:0]   s_axi_arqos,
   output logic         s_axi_arvalid,
   input logic          s_axi_arready,
   // Slave Interface Read Data Ports
   output logic         s_axi_rready,
   input logic [3:0]    s_axi_rid,
   input logic [127:0]  s_axi_rdata,
   input logic [1:0]    s_axi_rresp,
   input logic          s_axi_rlast,
   input logic          s_axi_rvalid,
   // }
   // I/O {
   // Slave Interface Write Address Ports
   output logic [3:0]   io_awid,
   output logic [27:0]  io_awaddr,
   output logic [7:0]   io_awlen,
   output logic [2:0]   io_awsize,
   output logic [1:0]   io_awburst,
   output logic [0:0]   io_awlock,
   output logic [3:0]   io_awcache,
   output logic [2:0]   io_awprot,
   output logic [3:0]   io_awqos,
   output logic         io_awvalid,
   input logic          io_awready,
   // Slave Interface Write Data Ports
   output logic [7:0]   io_wdata,
   output logic [15:0]  io_wstrb,
   output logic         io_wlast,
   output logic         io_wvalid,
   input logic          io_wready,
   // Slave Interface Write Response Ports
   output logic         io_bready,
   input logic [3:0]    io_bid,
   input logic [1:0]    io_bresp,
   input logic          io_bvalid,
   // Slave Interface Read Address Ports
   output logic [3:0]   io_arid,
   output logic [27:0]  io_araddr,
   output logic [7:0]   io_arlen,
   output logic [2:0]   io_arsize,
   output logic [1:0]   io_arburst,
   output logic [0:0]   io_arlock,
   output logic [3:0]   io_arcache,
   output logic [2:0]   io_arprot,
   output logic [3:0]   io_arqos,
   output logic         io_arvalid,
   input logic          io_arready,
   // Slave Interface Read Data Ports
   output logic         io_rready,
   input logic [3:0]    io_rid,
   input logic [7:0]    io_rdata,
   input logic [1:0]    io_rresp,
   input logic          io_rlast,
   input logic          io_rvalid,
   // }
   input logic          sys_rst_n
   );

   wire                nrst;

   wire [RSV_ID_W-1:0] mmu_rsv_id;
   wire                mmu_valid;
   wire [DATA_W-1:0]   mmu_data;
   wire [DATA_W-1:0]   mmu_addr;
   wire [INSTR_W-1:0]  mmu_opcode;
   wire                mmu_ready;

   wire [CDB_W-1:0]    mmu_cdb;
   wire                mmu_cdb_valid;
   wire                mmu_cdb_ready;

   assign nrst = sys_rst_n;

   core core_inst
     (
      .*
      );

   memory_management_unit mmu_inst
     (
      .*,
      .rsv_id(mmu_rsv_id),
      .valid(mmu_valid),
      .data(mmu_data),
      .address(mmu_addr),
      .opcode(mmu_opcode),
      .ready(mmu_ready),
      .o_cdb(mmu_cdb),
      .o_cdb_valid(mmu_cdb_valid),
      .o_cdb_ready(mmu_cdb_ready)
      );

endmodule
