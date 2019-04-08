`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module gmem_cntrl_tb ();

   logic clk = 0;
   initial forever #5 clk <= ~clk;
   logic nrst = 'b1;

   logic start_kernel = 'b0;
   logic clean_cache = 'b0;
   logic WGsDispatched = 'b0;
   logic CUs_gmem_idle = 'b0;
   wire  finish_exec;

   logic cu_valid = 'b0;
   wire  cu_ready;
   logic [DATA_W/8-1:0] cu_we = 'b0;
   logic                cu_rnw = 'b0;
   logic                cu_atomic = 'b0;
   logic [N_CU_STATIONS_W-1:0] cu_atomic_sgntr = 'b0;

   logic [GMEM_WORD_ADDR_W-1:0] cu_rqst_addr = 'b0;
   logic [DATA_W-1:0]           cu_wrData = 'b0;
   wire                         rdAck;
   wire [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] rdAddr;
   wire [DATA_W*CACHE_N_BANKS-1:0]             rdData;
   wire [DATA_W-1:0]                           atomic_rdData; // for dest register of atomic inst
   wire                                        atomic_rdData_v;
   wire [N_CU_STATIONS_W-1:0]                  atomic_sgntr;

   // Read Address Channel
   wire [GMEM_ADDR_W-1:0]                      axi_araddr;
   wire                                        axi_arvalid;
   wire                                        axi_arready;
   wire [ID_WIDTH-1:0]                         axi_arid;
   // Read Data Channel
   wire [DATA_W*GMEM_N_BANK-1:0]               axi_rdata;
   wire                                        axi_rlast;
   wire                                        axi_rvalid;
   wire                                        axi_rready;
   wire [ID_WIDTH-1:0]                         axi_rid;
   // Write Address Channel
   wire [GMEM_ADDR_W-1:0]                      axi_awaddr;
   wire                                        axi_awvalid;
   wire                                        axi_awready;
   wire [ID_WIDTH-1:0]                         axi_awid;
   // Write Data Channel
   wire [DATA_W*GMEM_N_BANK-1:0]               axi_wdata;
   wire [DATA_W*GMEM_N_BANK/8-1:0]             axi_wstrb;
   wire                                        axi_wlast;
   wire                                        axi_wvalid;
   wire                                        axi_wready;
   // Write Response Channel
   wire                                        axi_bvalid;
   wire                                        axi_bready;
   wire [ID_WIDTH-1:0]                         axi_bid;

   gmem_cntrl gmem_cntrl_inst
     (
      .*
      );

   global_mem global_mem_inst
     (
      .clk(clk),
      .m0_araddr(axi_araddr),
      .m0_arlen(8'(2**BURST_W-1)),
      .m0_arvalid(axi_arvalid),
      .m0_arready(axi_arready),
      .m0_arid(axi_arid),
      .m0_rdata(axi_rdata),
      .m0_rlast(axi_rlast),
      .m0_rvalid(axi_rvalid),
      .m0_rready(axi_rready),
      .m0_rid(axi_rid),
      .m0_awaddr(axi_awaddr),
      .m0_awlen(8'(2**BURST_W-1)),
      .m0_awvalid(axi_awvalid),
      .m0_awready(axi_awready),
      .m0_awid(axi_awid),
      .m0_wvalid(axi_wvalid),
      .m0_wdata(axi_wdata),
      .m0_wstrb(axi_wstrb),
      .m0_wlast(axi_wlast),
      .m0_wready(axi_wready),
      .m0_bvalid(axi_bvalid),
      .m0_bready(axi_bready),
      .m0_bid(axi_bid),
      .nrst(nrst)
      );

endmodule
