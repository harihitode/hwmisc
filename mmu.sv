`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module memory_management_unit
  (
   input logic                      clk,
   // core to mmu {
   input logic [RSV_ID_W-1:0]       rsv_id,
   input logic                      valid,
   input logic [DATA_W-1:0]         data,
   input logic [DATA_W-1:0]         address,
   input logic [INSTR_W-1:0]        opcode,
   output logic                     ready,
   // }
   // GMEM {
   // Slave Interface Write Address Ports
   output logic [ID_WIDTH-1:0]      s_axi_awid,
   output logic [GMEM_ADDR_W-1:0]   s_axi_awaddr,
   output logic [7:0]               s_axi_awlen,
   output logic [2:0]               s_axi_awsize,
   output logic [1:0]               s_axi_awburst,
   output logic [0:0]               s_axi_awlock,
   output logic [3:0]               s_axi_awcache,
   output logic [2:0]               s_axi_awprot,
   output logic [3:0]               s_axi_awqos,
   output logic                     s_axi_awvalid,
   input logic                      s_axi_awready,
   // Slave Interface Write Data Ports
   output logic [GMEM_DATA_W-1:0]   s_axi_wdata,
   output logic [GMEM_DATA_W/8-1:0] s_axi_wstrb,
   output logic                     s_axi_wlast,
   output logic                     s_axi_wvalid,
   input logic                      s_axi_wready,
   // Slave Interface Write Response Ports
   output logic                     s_axi_bready,
   input logic [ID_WIDTH-1:0]       s_axi_bid,
   input logic [1:0]                s_axi_bresp,
   input logic                      s_axi_bvalid,
   // Slave Interface Read Address Ports
   output logic [ID_WIDTH-1:0]      s_axi_arid,
   output logic [GMEM_ADDR_W-1:0]   s_axi_araddr,
   output logic [7:0]               s_axi_arlen,
   output logic [2:0]               s_axi_arsize,
   output logic [1:0]               s_axi_arburst,
   output logic [0:0]               s_axi_arlock,
   output logic [3:0]               s_axi_arcache,
   output logic [2:0]               s_axi_arprot,
   output logic [3:0]               s_axi_arqos,
   output logic                     s_axi_arvalid,
   input logic                      s_axi_arready,
   // Slave Interface Read Data Ports
   output logic                     s_axi_rready,
   input logic [ID_WIDTH-1:0]       s_axi_rid,
   input logic [GMEM_DATA_W-1:0]    s_axi_rdata,
   input logic [1:0]                s_axi_rresp,
   input logic                      s_axi_rlast,
   input logic                      s_axi_rvalid,
   // }
   // I/O {
   // Slave Interface Write Address Ports
   output logic [ID_WIDTH-1:0]      io_awid,
   output logic [27:0]              io_awaddr,
   output logic [7:0]               io_awlen,
   output logic [2:0]               io_awsize,
   output logic [1:0]               io_awburst,
   output logic [0:0]               io_awlock,
   output logic [3:0]               io_awcache,
   output logic [2:0]               io_awprot,
   output logic [3:0]               io_awqos,
   output logic                     io_awvalid,
   input logic                      io_awready,
   // Slave Interface Write Data Ports
   output logic [7:0]               io_wdata,
   output logic [15:0]              io_wstrb,
   output logic                     io_wlast,
   output logic                     io_wvalid,
   input logic                      io_wready,
   // Slave Interface Write Response Ports
   output logic                     io_bready,
   input logic [ID_WIDTH-1:0]       io_bid,
   input logic [1:0]                io_bresp,
   input logic                      io_bvalid,
   // Slave Interface Read Address Ports
   output logic [ID_WIDTH-1:0]      io_arid,
   output logic [27:0]              io_araddr,
   output logic [7:0]               io_arlen,
   output logic [2:0]               io_arsize,
   output logic [1:0]               io_arburst,
   output logic [0:0]               io_arlock,
   output logic [3:0]               io_arcache,
   output logic [2:0]               io_arprot,
   output logic [3:0]               io_arqos,
   output logic                     io_arvalid,
   input logic                      io_arready,
   // Slave Interface Read Data Ports
   output logic                     io_rready,
   input logic [ID_WIDTH-1:0]       io_rid,
   input logic [7:0]                io_rdata,
   input logic [1:0]                io_rresp,
   input logic                      io_rlast,
   input logic                      io_rvalid,
   // }
   // CRAM {
   // cram addr ports
   output logic [3:0]               cram_arid = 'b0,
   output logic [31:0]              cram_araddr = 'b0,
   output logic [7:0]               cram_arlen = 'b0,
   output logic [2:0]               cram_arsize = 'b0,
   output logic [1:0]               cram_arburst = 'b0,
   output logic [0:0]               cram_arlock = 'b0,
   output logic [3:0]               cram_arcache = 'b0,
   output logic [2:0]               cram_arprot = 'b0,
   output logic [3:0]               cram_arqos = 'b0,
   output logic                     cram_arvalid = 'b0,
   input logic                      cram_arready,
   // cram data ports
   output logic                     cram_rready = 'b0,
   input logic [3:0]                cram_rid,
   input logic [31:0]               cram_rdata,
   input logic [1:0]                cram_rresp,
   input logic                      cram_rlast,
   input logic                      cram_rvalid,
   // }

   output logic [CDB_W-1:0]         o_cdb,
   output logic                     o_cdb_valid,
   input logic                      o_cdb_ready,

   input logic                      nrst
   );

   logic [RSV_ID_W-1:0]      rsv_id_d = 'b0;
   logic [DATA_W-1:0]        address_d = 'b0;
   logic [DATA_W-1:0]        data_d = 'b0;
   logic [INSTR_W-1:0]       opcode_d = 'b0;

   typedef enum              {mmu_idle, mmu_wr_addr, mmu_wr_data, mmu_rd_addr, mmu_rd_data} st_mmu_t;
   st_mmu_t state;
   st_mmu_t state_n = mmu_idle;

   // static signals for MEM {
   assign s_axi_awid = 4'b0;
   assign s_axi_awprot = 'b0;
   assign s_axi_awlock = 'b0;
   assign s_axi_awcache = 'h0;
   assign s_axi_awqos = 'b0;
   assign s_axi_awburst = 'b1;
   assign s_axi_awlen = ($size(s_axi_awlen))'($unsigned((2**BURST_W)-1));  // once per burst
   assign s_axi_awsize = 3'($unsigned(2+GMEM_N_BANK_W)); // 2*2 = 4bytes(32bits)

   assign s_axi_arid = 4'b0;
   assign s_axi_arprot = 'b0;
   assign s_axi_arlock = 'b0;
   assign s_axi_arcache = 'h0;
   assign s_axi_arqos = 'b0;
   assign s_axi_arburst = 'b1;
   assign s_axi_arlen = ($size(s_axi_arlen))'($unsigned((2**BURST_W)-1));
   assign s_axi_arsize = 3'($unsigned(2+GMEM_N_BANK_W)); // 2*2 = 4bytes(32bits)
   // }

   assign s_axi_araddr = 28'(address_d);
   assign s_axi_awaddr = 28'(address_d);

   assign s_axi_wdata = 128'(data_d);
   assign s_axi_wstrb = 16'hffff;
   assign s_axi_bready = 'b1;

   // static signals for IO {
   assign io_awid = 4'b0;
   assign io_awprot = 'b0;
   assign io_awlock = 'b0;
   assign io_awcache = 'h0;
   assign io_awqos = 'b0;
   assign io_awburst = 'b1;
   assign io_awlen = 'h0;
   assign io_awsize = 'h4;

   assign io_arid = 4'b0;
   assign io_arprot = 'b0;
   assign io_arlock = 'b0;
   assign io_arcache = 'h0;
   assign io_arqos = 'b0;
   assign io_arburst = 'b1;
   assign io_arlen = 'h0;
   assign io_arsize = 'h4;
   // }

   assign io_araddr = 28'(address_d);
   assign io_arvalid = 'b0;
   assign io_awaddr = 28'(address_d);
   assign io_awvalid = 'b0;

   assign io_wstrb = 16'hffff;
   assign io_bready = 'b1;

   // serial interface {
   always_comb begin
      if (state == mmu_idle && valid && opcode == I_OUTPUT) begin
         io_wvalid <= 'b1;
         io_wlast <= 'b1;
         io_wdata <= data;
      end else begin
         io_wvalid <= 'b0;
         io_wlast <= 'b0;
         io_wdata <= 'b0;
      end
   end
   // }

   always_comb begin
      s_axi_awvalid <= 'b0;
      s_axi_wvalid <= 'b0;
      s_axi_wlast <= 'b0;
      if (state == mmu_wr_addr) begin
         s_axi_awvalid <= 'b1;
      end else if (state == mmu_wr_data) begin
         s_axi_wvalid <= 'b1;
         s_axi_wlast <= 'b1;
      end
   end

   always_comb begin
      s_axi_arvalid <= 'b0;
      if (state == mmu_rd_addr) begin
         s_axi_arvalid <= 'b1;
      end
   end

   always_comb mmu_fsm : begin
      state_n <= state;
      if (state == mmu_idle) begin
         if (valid && ready) begin
            case (opcode)
              I_STORE, I_STOREB, I_STORER : begin
//              I_STOREF, I_STOREBF, I_STORERF : begin
                 state_n <= mmu_wr_addr;
              end
              I_LOAD, I_LOADB, I_LOADR : begin
//              I_LOADF, I_LOADBF, I_LOADRF : begin
                 state_n <= mmu_rd_addr;
              end
              default : begin
                 state_n <= state;
              end
            endcase
         end
      end else if (state == mmu_wr_addr) begin
         if (s_axi_awvalid && s_axi_awready) begin
            state_n <= mmu_wr_data;
         end
      end else if (state == mmu_wr_data) begin
         if (s_axi_wvalid && s_axi_wready) begin
            state_n <= mmu_idle;
         end
      end else if (state == mmu_rd_addr) begin
         if (s_axi_arvalid && s_axi_arready) begin
            state_n <= mmu_rd_data;
         end
      end else if (state == mmu_rd_data) begin
         if (s_axi_rvalid && s_axi_rready) begin
            state_n <= mmu_idle;
         end
      end
   end

   always_comb core_ready : begin
      if (state == mmu_idle && opcode == I_OUTPUT) begin
         ready <= io_wready;
      end else if (state == mmu_idle && (opcode == I_INPUT)) begin
         ready <= io_rvalid;
      end else if (state == mmu_idle) begin
         ready <= 'b1;
      end else begin
         ready <= 'b0;
      end
   end

   always_comb begin
      o_cdb_valid <= 'b0;
      o_cdb <= 'b0;
      io_rready <= 'b0;
      s_axi_rready <= 'b0;
      if (valid && (opcode == I_INPUT)) begin
         o_cdb_valid <= io_rvalid;
         o_cdb <= {rsv_id, 32'(io_rdata)};
         io_rready <= o_cdb_ready;
      end else if (state == mmu_rd_data) begin
         o_cdb_valid <= s_axi_rvalid;
         o_cdb <= {rsv_id_d, s_axi_rdata[31:0]};
         s_axi_rready <= o_cdb_ready;
      end
   end // always_comb

   always_ff @(posedge clk) begin
      if (nrst) begin
         state <= state_n;
         if (state == mmu_idle && // idle
             valid && ready) begin
            rsv_id_d <= rsv_id;
            address_d <= address;
            data_d <= data;
            opcode_d <= opcode;
         end
      end else begin
         state <= mmu_idle;
         rsv_id_d <= 'b0;
         address_d <= 'b0;
         data_d <= 'b0;
         opcode_d <= 'b0;
      end
   end

endmodule
