`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
   // clk & reset
   input logic                             clk,
   // CRAM {
   // cram addr ports
   output logic [3:0]                      s_cram_arid,
   output logic [31:0]                     s_cram_araddr,
   output logic [7:0]                      s_cram_arlen,
   output logic [2:0]                      s_cram_arsize,
   output logic [1:0]                      s_cram_arburst,
   output logic [0:0]                      s_cram_arlock,
   output logic [3:0]                      s_cram_arcache,
   output logic [2:0]                      s_cram_arprot,
   output logic [3:0]                      s_cram_arqos,
   output logic                            s_cram_arvalid,
   input logic                             s_cram_arready,
   // cram data ports
   output logic                            s_cram_rready,
   input logic [3:0]                       s_cram_rid,
   input logic [31:0]                      s_cram_rdata,
   input logic [1:0]                       s_cram_rresp,
   input logic                             s_cram_rlast,
   input logic                             s_cram_rvalid,
   // }
   // DDR {
   // Slave Interface Write Data Ports
   output logic [ID_WIDTH-1:0]             s_axi_awid,
   output logic [GMEM_ADDR_W-1:0]          s_axi_awaddr,
   output logic [7:0]                      s_axi_awlen,
   output logic [2:0]                      s_axi_awsize,
   output logic [1:0]                      s_axi_awburst,
   output logic [0:0]                      s_axi_awlock,
   output logic [3:0]                      s_axi_awcache,
   output logic [2:0]                      s_axi_awprot,
   output logic [3:0]                      s_axi_awqos,
   output logic                            s_axi_awvalid,
   input logic                             s_axi_awready,
   // Slave Interface Write Data Ports
   output logic [DATA_W*GMEM_N_BANK-1:0]   s_axi_wdata,
   output logic [DATA_W*GMEM_N_BANK/8-1:0] s_axi_wstrb,
   output logic                            s_axi_wlast,
   output logic                            s_axi_wvalid,
   input logic                             s_axi_wready,
   // Slave Interface Write Response Ports
   output logic                            s_axi_bready,
   input logic [3:0]                       s_axi_bid,
   input logic [ID_WIDTH-1:0]              s_axi_bresp,
   input logic                             s_axi_bvalid,
   // Slave Interface Read Address Ports
   output logic [ID_WIDTH-1:0]             s_axi_arid,
   output logic [GMEM_ADDR_W-1:0]          s_axi_araddr,
   output logic [7:0]                      s_axi_arlen,
   output logic [2:0]                      s_axi_arsize,
   output logic [1:0]                      s_axi_arburst,
   output logic [0:0]                      s_axi_arlock,
   output logic [3:0]                      s_axi_arcache,
   output logic [2:0]                      s_axi_arprot,
   output logic [3:0]                      s_axi_arqos,
   output logic                            s_axi_arvalid,
   input logic                             s_axi_arready,
   // Slave Interface Read Data Ports
   output logic                            s_axi_rready,
   input logic [ID_WIDTH-1:0]              s_axi_rid,
   input logic [GMEM_DATA_W-1:0]           s_axi_rdata,
   input logic [1:0]                       s_axi_rresp,
   input logic                             s_axi_rlast,
   input logic                             s_axi_rvalid,
   // }
   // I/O {
   // Slave Interface Write Address Ports
   output logic [3:0]                      io_awid,
   output logic [27:0]                     io_awaddr,
   output logic [7:0]                      io_awlen,
   output logic [2:0]                      io_awsize,
   output logic [1:0]                      io_awburst,
   output logic [0:0]                      io_awlock,
   output logic [3:0]                      io_awcache,
   output logic [2:0]                      io_awprot,
   output logic [3:0]                      io_awqos,
   output logic                            io_awvalid,
   input logic                             io_awready,
   // Slave Interface Write Data Ports
   output logic [7:0]                      io_wdata,
   output logic [15:0]                     io_wstrb,
   output logic                            io_wlast,
   output logic                            io_wvalid,
   input logic                             io_wready,
   // Slave Interface Write Response Ports
   output logic                            io_bready,
   input logic [3:0]                       io_bid,
   input logic [1:0]                       io_bresp,
   input logic                             io_bvalid,
   // Slave Interface Read Address Ports
   output logic [3:0]                      io_arid,
   output logic [27:0]                     io_araddr,
   output logic [7:0]                      io_arlen,
   output logic [2:0]                      io_arsize,
   output logic [1:0]                      io_arburst,
   output logic [0:0]                      io_arlock,
   output logic [3:0]                      io_arcache,
   output logic [2:0]                      io_arprot,
   output logic [3:0]                      io_arqos,
   output logic                            io_arvalid,
   input logic                             io_arready,
   // Slave Interface Read Data Ports
   output logic                            io_rready,
   input logic [3:0]                       io_rid,
   input logic [7:0]                       io_rdata,
   input logic [1:0]                       io_rresp,
   input logic                             io_rlast,
   input logic                             io_rvalid,
   // }
   input logic                             sys_rst_n
   );

   // cram addr ports
   wire [3:0]                              s_mmu_cram_arid;
   wire [31:0]                             s_mmu_cram_araddr;
   wire [7:0]                              s_mmu_cram_arlen;
   wire [2:0]                              s_mmu_cram_arsize;
   wire [1:0]                              s_mmu_cram_arburst;
   wire [0:0]                              s_mmu_cram_arlock;
   wire [3:0]                              s_mmu_cram_arcache;
   wire [2:0]                              s_mmu_cram_arprot;
   wire [3:0]                              s_mmu_cram_arqos;
   wire                                    s_mmu_cram_arvalid;
   wire                                    s_mmu_cram_arready;

   // cram data ports
   wire [3:0]                              s_mmu_cram_rid;
   wire [31:0]                             s_mmu_cram_rdata;
   wire [1:0]                              s_mmu_cram_rresp;
   wire                                    s_mmu_cram_rlast;
   wire                                    s_mmu_cram_rvalid;
   wire                                    s_mmu_cram_rready;

   // cram addr ports
   wire [3:0]                              s_core_cram_arid;
   wire [31:0]                             s_core_cram_araddr;
   wire [7:0]                              s_core_cram_arlen;
   wire [2:0]                              s_core_cram_arsize;
   wire [1:0]                              s_core_cram_arburst;
   wire [0:0]                              s_core_cram_arlock;
   wire [3:0]                              s_core_cram_arcache;
   wire [2:0]                              s_core_cram_arprot;
   wire [3:0]                              s_core_cram_arqos;
   wire                                    s_core_cram_arvalid;
   wire                                    s_core_cram_arready;

   // cram data ports
   wire [3:0]                              s_core_cram_rid;
   wire [31:0]                             s_core_cram_rdata;
   wire [1:0]                              s_core_cram_rresp;
   wire                                    s_core_cram_rlast;
   wire                                    s_core_cram_rvalid;
   wire                                    s_core_cram_rready;

   wire                                    nrst;

   wire [RSV_ID_W-1:0]                     mmu_rsv_id;
   wire                                    mmu_valid;
   wire [DATA_W-1:0]                       mmu_data;
   wire [DATA_W-1:0]                       mmu_addr;
   wire [INSTR_W-1:0]                      mmu_opcode;
   wire                                    mmu_ready;

   wire [CDB_W-1:0]                        mmu_cdb;
   wire                                    mmu_cdb_valid;
   wire                                    mmu_cdb_ready;

   assign nrst = sys_rst_n;

   core core_inst
     (
      .s_cram_arid(s_core_cram_arid),
      .s_cram_araddr(s_core_cram_araddr),
      .s_cram_arlen(s_core_cram_arlen),
      .s_cram_arsize(s_core_cram_arsize),
      .s_cram_arburst(s_core_cram_arburst),
      .s_cram_arlock(s_core_cram_arlock),
      .s_cram_arcache(s_core_cram_arcache),
      .s_cram_arprot(s_core_cram_arprot),
      .s_cram_arqos(s_core_cram_arqos),
      .s_cram_arvalid(s_core_cram_arvalid),
      .s_cram_arready(s_core_cram_arready),
      .s_cram_rready(s_core_cram_rready),
      .s_cram_rid(s_core_cram_rid),
      .s_cram_rdata(s_core_cram_rdata),
      .s_cram_rresp(s_core_cram_rresp),
      .s_cram_rlast(s_core_cram_rlast),
      .s_cram_rvalid(s_core_cram_rvalid),
      .*
      );

   axi_interconnect_0 bus
     (
      .INTERCONNECT_ACLK(clk),
      .INTERCONNECT_ARESETN(sys_rst_n),
      .S00_AXI_ARESET_OUT_N(),
      .S00_AXI_ACLK(clk),
      .S00_AXI_AWID('b0),
      .S00_AXI_AWADDR('b0),
      .S00_AXI_AWLEN('b0),
      .S00_AXI_AWSIZE('b0),
      .S00_AXI_AWBURST('b1),
      .S00_AXI_AWLOCK('b0),
      .S00_AXI_AWCACHE('b0),
      .S00_AXI_AWPROT('b0),
      .S00_AXI_AWQOS('b0),
      .S00_AXI_AWVALID('b0),
      .S00_AXI_AWREADY(),
      .S00_AXI_WDATA('b0),
      .S00_AXI_WSTRB('b0),
      .S00_AXI_WLAST('b0),
      .S00_AXI_WVALID('b0),
      .S00_AXI_WREADY(),
      .S00_AXI_BID(),
      .S00_AXI_BRESP(),
      .S00_AXI_BVALID(),
      .S00_AXI_BREADY('b0),
      .S00_AXI_ARID(s_core_cram_arid),
      .S00_AXI_ARADDR(s_core_cram_araddr),
      .S00_AXI_ARLEN(s_core_cram_arlen),
      .S00_AXI_ARSIZE(s_core_cram_arsize),
      .S00_AXI_ARBURST(s_core_cram_arburst),
      .S00_AXI_ARLOCK(s_core_cram_arlock),
      .S00_AXI_ARCACHE(s_core_cram_arcache),
      .S00_AXI_ARPROT(s_core_cram_arprot),
      .S00_AXI_ARQOS(s_core_cram_arqos),
      .S00_AXI_ARVALID(s_core_cram_arvalid),
      .S00_AXI_ARREADY(s_core_cram_arready),
      .S00_AXI_RID(s_core_cram_rid),
      .S00_AXI_RDATA(s_core_cram_rdata),
      .S00_AXI_RRESP(s_core_cram_rresp),
      .S00_AXI_RLAST(s_core_cram_rlast),
      .S00_AXI_RVALID(s_core_cram_rvalid),
      .S00_AXI_RREADY(s_core_cram_rready),
      .S01_AXI_ARESET_OUT_N(),
      .S01_AXI_ACLK(clk),
      .S01_AXI_AWID('b0),
      .S01_AXI_AWADDR('b0),
      .S01_AXI_AWLEN('b0),
      .S01_AXI_AWSIZE('b0),
      .S01_AXI_AWBURST('b1),
      .S01_AXI_AWLOCK('b0),
      .S01_AXI_AWCACHE('b0),
      .S01_AXI_AWPROT('b0),
      .S01_AXI_AWQOS('b0),
      .S01_AXI_AWVALID('b0),
      .S01_AXI_AWREADY(),
      .S01_AXI_WDATA('b0),
      .S01_AXI_WSTRB('b0),
      .S01_AXI_WLAST('b0),
      .S01_AXI_WVALID('b0),
      .S01_AXI_WREADY(),
      .S01_AXI_BID(),
      .S01_AXI_BRESP(),
      .S01_AXI_BVALID(),
      .S01_AXI_BREADY('b0),
      .S01_AXI_ARID(s_mmu_cram_arid),
      .S01_AXI_ARADDR(s_mmu_cram_araddr),
      .S01_AXI_ARLEN(s_mmu_cram_arlen),
      .S01_AXI_ARSIZE(s_mmu_cram_arsize),
      .S01_AXI_ARBURST(s_mmu_cram_arburst),
      .S01_AXI_ARLOCK(s_mmu_cram_arlock),
      .S01_AXI_ARCACHE(s_mmu_cram_arcache),
      .S01_AXI_ARPROT(s_mmu_cram_arprot),
      .S01_AXI_ARQOS(s_mmu_cram_arqos),
      .S01_AXI_ARVALID(s_mmu_cram_arvalid),
      .S01_AXI_ARREADY(s_mmu_cram_arready),
      .S01_AXI_RID(s_mmu_cram_rid),
      .S01_AXI_RDATA(s_mmu_cram_rdata),
      .S01_AXI_RRESP(s_mmu_cram_rresp),
      .S01_AXI_RLAST(s_mmu_cram_rlast),
      .S01_AXI_RVALID(s_mmu_cram_rvalid),
      .S01_AXI_RREADY(s_mmu_cram_rready),
      .M00_AXI_ARESET_OUT_N(),
      .M00_AXI_ACLK(clk),
      .M00_AXI_AWID(),
      .M00_AXI_AWADDR(),
      .M00_AXI_AWLEN(),
      .M00_AXI_AWSIZE(),
      .M00_AXI_AWBURST(),
      .M00_AXI_AWLOCK(),
      .M00_AXI_AWCACHE(),
      .M00_AXI_AWPROT(),
      .M00_AXI_AWQOS(),
      .M00_AXI_AWVALID(),
      .M00_AXI_AWREADY('b0),
      .M00_AXI_WDATA(),
      .M00_AXI_WSTRB(),
      .M00_AXI_WLAST(),
      .M00_AXI_WVALID(),
      .M00_AXI_WREADY('b0),
      .M00_AXI_BID('b0),
      .M00_AXI_BRESP('b0),
      .M00_AXI_BVALID('b0),
      .M00_AXI_BREADY(),
      .M00_AXI_ARID(s_cram_arid),
      .M00_AXI_ARADDR(s_cram_araddr),
      .M00_AXI_ARLEN(s_cram_arlen),
      .M00_AXI_ARSIZE(s_cram_arsize),
      .M00_AXI_ARBURST(s_cram_arburst),
      .M00_AXI_ARCACHE(s_cram_arcache),
      .M00_AXI_ARLOCK(s_cram_arlock),
      .M00_AXI_ARPROT(s_cram_arprot),
      .M00_AXI_ARQOS(s_cram_arqos),
      .M00_AXI_ARVALID(s_cram_arvalid),
      .M00_AXI_ARREADY(s_cram_arready),
      .M00_AXI_RID(s_cram_rid),
      .M00_AXI_RDATA(s_cram_rdata),
      .M00_AXI_RRESP(s_cram_rresp),
      .M00_AXI_RLAST(s_cram_rlast),
      .M00_AXI_RVALID(s_cram_rvalid),
      .M00_AXI_RREADY(s_cram_rready)
      );

   memory_management_unit mmu_inst
     (
      .*,
      .cram_arid(s_mmu_cram_arid),
      .cram_araddr(s_mmu_cram_araddr),
      .cram_arlen(s_mmu_cram_arlen),
      .cram_arsize(s_mmu_cram_arsize),
      .cram_arburst(s_mmu_cram_arburst),
      .cram_arlock(s_mmu_cram_arlock),
      .cram_arcache(s_mmu_cram_arcache),
      .cram_arprot(s_mmu_cram_arprot),
      .cram_arqos(s_mmu_cram_arqos),
      .cram_arvalid(s_mmu_cram_arvalid),
      .cram_arready(s_mmu_cram_arready),
      .cram_rready(s_mmu_cram_rready),
      .cram_rid(s_mmu_cram_rid),
      .cram_rdata(s_mmu_cram_rdata),
      .cram_rresp(s_mmu_cram_rresp),
      .cram_rlast(s_mmu_cram_rlast),
      .cram_rvalid(s_mmu_cram_rvalid),
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
