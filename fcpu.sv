`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
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
   input logic [ID_WIDTH-1:0]              s_axi_bid,
   input logic [1:0]                       s_axi_bresp,
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
   input logic [DATA_W*GMEM_N_BANK-1:0]    s_axi_rdata,
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
   // clk & reset
   input logic                             clk,
   input logic                             sys_rst_n,
   output logic                            halt
   );

   // cram addr ports
   wire [0:0]                              s_mmu_cram_arid;
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
   wire [0:0]                              s_mmu_cram_rid;
   wire [31:0]                             s_mmu_cram_rdata;
   wire [1:0]                              s_mmu_cram_rresp;
   wire                                    s_mmu_cram_rlast;
   wire                                    s_mmu_cram_rvalid;
   wire                                    s_mmu_cram_rready;

   // cram addr ports
   wire [0:0]                              s_core_cram_arid;
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
   wire [0:0]                              s_core_cram_rid;
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

   axi_crossbar_0 bus
     (
      .aclk(clk),
      .aresetn(sys_rst_n),
      .s_axi_awid('0),
      .s_axi_awaddr('0),
      .s_axi_awlen('0),
      .s_axi_awsize('0),
      .s_axi_awburst('0),
      .s_axi_awlock('0),
      .s_axi_awcache('0),
      .s_axi_awprot('0),
      .s_axi_awqos('0),
      .s_axi_awvalid('0),
      .s_axi_awready(),
      .s_axi_wdata('0),
      .s_axi_wstrb('0),
      .s_axi_wlast('0),
      .s_axi_wvalid('0),
      .s_axi_wready(),
      .s_axi_bid(),
      .s_axi_bresp(),
      .s_axi_bvalid(),
      .s_axi_bready('1),
      .s_axi_arid({s_core_cram_arid, s_mmu_cram_arid}),
      .s_axi_araddr({s_core_cram_araddr, s_mmu_cram_araddr}),
      .s_axi_arlen({s_core_cram_arlen, s_mmu_cram_arlen}),
      .s_axi_arsize({s_core_cram_arsize, s_mmu_cram_arsize}),
      .s_axi_arburst({s_core_cram_arburst, s_mmu_cram_arburst}),
      .s_axi_arlock({s_core_cram_arlock, s_mmu_cram_arlock}),
      .s_axi_arcache({s_core_cram_arcache, s_mmu_cram_arcache}),
      .s_axi_arprot({s_core_cram_arprot, s_mmu_cram_arprot}),
      .s_axi_arqos({s_core_cram_arqos, s_mmu_cram_arqos}),
      .s_axi_arvalid({s_core_cram_arvalid, s_mmu_cram_arvalid}),
      .s_axi_arready({s_core_cram_arready, s_mmu_cram_arready}),
      .s_axi_rid({s_core_cram_rid, s_mmu_cram_rid}),
      .s_axi_rdata({s_core_cram_rdata, s_mmu_cram_rdata}),
      .s_axi_rresp({s_core_cram_rresp, s_mmu_cram_rresp}),
      .s_axi_rlast({s_core_cram_rlast, s_mmu_cram_rlast}),
      .s_axi_rvalid({s_core_cram_rvalid, s_mmu_cram_rvalid}),
      .s_axi_rready({s_core_cram_rready, s_mmu_cram_rready}),

      .m_axi_awid(),
      .m_axi_awaddr(),
      .m_axi_awlen(),
      .m_axi_awsize(),
      .m_axi_awburst(),
      .m_axi_awlock(),
      .m_axi_awcache(),
      .m_axi_awprot(),
      .m_axi_awqos(),
      .m_axi_awvalid(),
      .m_axi_awready('0),
      .m_axi_wdata(),
      .m_axi_wstrb(),
      .m_axi_wlast(),
      .m_axi_wvalid(),
      .m_axi_wready('0),
      .m_axi_bid('0),
      .m_axi_bresp('0),
      .m_axi_bvalid('0),
      .m_axi_bready(),

      .m_axi_arid(s_cram_arid),
      .m_axi_araddr(s_cram_araddr),
      .m_axi_arlen(s_cram_arlen),
      .m_axi_arsize(s_cram_arsize),
      .m_axi_arburst(s_cram_arburst),
      .m_axi_arcache(s_cram_arcache),
      .m_axi_arlock(s_cram_arlock),
      .m_axi_arprot(s_cram_arprot),
      .m_axi_arqos(s_cram_arqos),
      .m_axi_arvalid(s_cram_arvalid),
      .m_axi_arready(s_cram_arready),
      .m_axi_rid(s_cram_rid),
      .m_axi_rdata(s_cram_rdata),
      .m_axi_rresp(s_cram_rresp),
      .m_axi_rlast(s_cram_rlast),
      .m_axi_rvalid(s_cram_rvalid),
      .m_axi_rready(s_cram_rready)
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
