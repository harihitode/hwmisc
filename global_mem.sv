`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

const real MATH_PI = 3.14159265;

module global_mem
  #(parameter int MEM_PHY_ADDR_W = 17,
    parameter unsigned ADDR_OFFSET = 'h10000000,
    parameter int MAX_NDRANGE_SIZE = 64*1024)
   (
    // axi slave interface
    // interface 0 {
    // ar channel
    input logic [GMEM_ADDR_W-1:0]   m0_araddr,
    input logic [7:0]               m0_arlen,
    input logic                     m0_arvalid,
    output logic                    m0_arready,
    input logic [ID_WIDTH-1:0]      m0_arid,
    // r channel
    output logic [GMEM_DATA_W-1:0]  m0_rdata,
    output logic                    m0_rlast,
    output logic                    m0_rvalid,
    input logic                     m0_rready,
    output logic [ID_WIDTH-1:0]     m0_rid,
    // aw channel
    input logic [GMEM_ADDR_W-1:0]   m0_awaddr,
    input logic [7:0]               m0_awlen,
    input logic                     m0_awvalid,
    output logic                    m0_awready,
    input logic [ID_WIDTH-1:0]      m0_awid,
    // w channel
    input logic [GMEM_DATA_W-1:0]   m0_wdata,
    input logic [GMEM_DATA_W/8-1:0] m0_wstrb,
    input logic                     m0_wlast,
    input logic                     m0_wvalid,
    output logic                    m0_wready,
    // b channel
    output logic                    m0_bvalid,
    input logic                     m0_bready,
    output logic [ID_WIDTH-1:0]     m0_bid,
    // }
    input logic                     clk,
    input logic                     nrst
    );
   localparam int                   C_MEM_SIZE = 2**MEM_PHY_ADDR_W;
   localparam real                  MAX_DELAY = 20.0;
   localparam int                   MIN_DELAY = 10;
   localparam int                   IMPLEMENT_DELAY = 0;
   localparam real                  MAX_STEAM_PAUSE = 15.0;
   localparam int                   IMPLEMENT_NO_STREAM_READ = 0;
   localparam int                   FILL_MODULO = 49;
   localparam int                   BVALID_DELAY_W = 2;

   // read & write addresses {
   logic [C_MEM_SIZE-1:0][GMEM_DATA_W-1:0] gmem = 'b0;

   logic [GMEM_ADDR_W-1:0] wr_addr = '0;
   wire [MEM_PHY_ADDR_W-1:0] wr_addr_offset;
   int                                  written_count = 0;
   logic [MAX_NDRANGE_SIZE-1:0]         written_addrs = '0;
   // }

   // other signals {
   int                                  delay = 0;
   // }
   // alias signals {
   logic                     wvalid = '0;
   logic                     wready = '0;
   logic [DATA_W*GMEM_N_BANK-1:0] wdata = '0;
   logic [DATA_W*GMEM_N_BANK-1:0] rdata = '0;
   logic [GMEM_N_BANK*DATA_W/8-1:0] wstrb = '0;
   wire                             awready;
   logic                            awvalid = '0;
   logic                            arready = '0;
   logic                            arvalid = '0;
   logic                            rready = '0;
   logic                            rvalid = '0;
   logic                            rlast = '0;
   logic                            bready = '0;
   logic                            bvalid = '0;
   logic [GMEM_ADDR_W-1:0]          araddr = '0;
   logic [GMEM_ADDR_W-1:0]          awaddr = '0;
   logic [ID_WIDTH-1:0]             arid = '0;
   logic [ID_WIDTH-1:0]             rid = '0;
   logic [ID_WIDTH-1:0]             awid = '0;
   logic [ID_WIDTH-1:0]             bid = '0;
   logic                            wlast = '0;
   // }
   // write signals {
   localparam C_AWADDR_FIFO_CAPACITY_W = 3;
   localparam C_AWADDR_FIFO_CAPACITY = 2**C_AWADDR_FIFO_CAPACITY_W;
   // }
   // awaddr fifo
   logic [C_AWADDR_FIFO_CAPACITY-1:0][GMEM_ADDR_W-1:0] awaddr_fifo = '0;
   logic [C_AWADDR_FIFO_CAPACITY_W-1:0]                awaddr_fifo_wrAddr = '0;
   logic [C_AWADDR_FIFO_CAPACITY_W-1:0]                awaddr_fifo_rdAddr = '0;
   logic                                               awaddr_fifo_nempty = '0;
   logic                                               awaddr_fifo_full = '0;
   logic                                               awaddr_fifo_pop = '0;
   wire                                                awaddr_fifo_push;
   // awid fifo
   logic [((BURST_W > BVALID_DELAY_W) ? 1 : (2**BVALID_DELAY_W/2**BURST_W)) * C_AWADDR_FIFO_CAPACITY-1:0][ID_WIDTH-1:0] awid_fifo = '0;
   logic [C_AWADDR_FIFO_CAPACITY_W+((BURST_W > BVALID_DELAY_W) ? 0 : BVALID_DELAY_W-BURST_W)-1:0]                       awid_fifo_rdAddr = '0;
   logic [C_AWADDR_FIFO_CAPACITY_W+((BURST_W > BVALID_DELAY_W) ? 0 : BVALID_DELAY_W-BURST_W)-1:0]                       awid_fifo_wrAddr = '0;

   typedef enum                                                                                                         {get_address, write_data} st_write_type;
   st_write_type st_write = get_address;
   // write pipe for delaying bvalid
   logic [2**BVALID_DELAY_W-1:0][DATA_W*GMEM_N_BANK-1:0]                                                                        wdata_vec = '0;
   logic [2**BVALID_DELAY_W-1:0][GMEM_N_BANK*DATA_W/8-1:0]                                                                      wstrb_vec = '0;

   logic [2**BVALID_DELAY_W-1:0]                                                                                                wlast_vec = '0;
   logic [2**BVALID_DELAY_W-1:0]                                                                                                wvalid_vec = '0;
   logic [2**BVALID_DELAY_W-1:0][MEM_PHY_ADDR_W-1:0]                                                                            wr_addr_offset_vec = '0;
   // }

   // alias
   always_comb begin
      wvalid <= m0_wvalid;
      wdata <= m0_wdata;
      wstrb <= m0_wstrb;
      wlast <= m0_wlast;
      m0_wready <= wready;
      m0_awready <= awready;
      awvalid <= m0_awvalid;
      awaddr <= $unsigned(m0_awaddr);
      araddr <= $unsigned(m0_araddr);
      m0_arready <= arready;
      arvalid <= m0_arvalid;
      arid <= m0_arid;
      rready <= m0_rready;
      m0_rvalid <= rvalid;
      m0_rid <= rid;
      awid <= m0_awid;
      m0_bid <= bid;
      m0_rdata <= rdata;
      m0_rlast <= rlast;
      m0_bvalid <= bvalid;
      bready <= m0_bready;
   end // always_comb

   // mem module {
   always_ff @(posedge clk) begin
      if (wvalid_vec[0] && wready) begin
         for (int i = 0; i < GMEM_DATA_W/8; i++) begin
            if (wstrb_vec[0][i]) begin
               gmem[$unsigned(wr_addr_offset_vec[0])][(i*8)+:8] <= wdata_vec[0][(i*8)+:8];
            end
         end
      end
   end
   // }

   typedef enum {reader_idle, delay_before_read, send_data} st_reader_type;

   // read control {
   always_ff @(posedge clk) begin
      static int unsigned rdAddr = 0;
      static st_reader_type st_reader = reader_idle;
      static int unsigned rlen = 0;

      if (nrst) begin
         arready <= 'b0;
         rvalid <= 'b0;
         rlast <= 'b0;
         // id readers

         case (st_reader)
           reader_idle : begin
              if (arvalid && !arready && $unsigned(arid == 0)) begin
                 arready <= 'b1;
                 rdAddr = $unsigned(araddr) - ADDR_OFFSET;
                 rlen = $unsigned(m0_arlen);

                 if (IMPLEMENT_DELAY) begin
                    st_reader <= delay_before_read;
                    delay <= MIN_DELAY + $floor($itor($urandom()) / $itor(32'hffffffff) * MAX_DELAY);
                 end else begin
                    st_reader <= send_data;
                 end
              end
           end
           delay_before_read : begin
              if (delay != 0) begin
                 delay <= delay - 1;
              end else begin
                 st_reader <= send_data;
              end
           end
           send_data : begin
              rdAddr <= rdAddr + 8;
              if (rlen == 0) begin
                 st_reader <= reader_idle;
              end else begin
                 rlen <= rlen - 1;
                 if (IMPLEMENT_NO_STREAM_READ) begin
                    if ($itor($uniform())/$itor(32'hffffffff) < 0.5) begin
                       delay <= $floor($itor($urandom()) / $itor(32'hffffffff) * MAX_STEAM_PAUSE);
                       st_reader <= delay_before_read;
                    end
                 end
              end
           end
         endcase

         if (st_reader == send_data)  begin
            rvalid <= 'b1;
            rdata <= gmem[$unsigned(rdAddr[MEM_PHY_ADDR_W+2+GMEM_N_BANK_W-1:2+GMEM_N_BANK_W])];
            rid <= (ID_WIDTH)'($unsigned(0));
            if (rlen == 0) begin
               if (rlen == 0) begin
                  rlast <= 'b1;
               end
            end
         end

      end // if (nrst)
   end // always_ff @ (posedge clk)
   // }

   int tmp = 0;
   // write control {

   assign wr_addr_offset = wr_addr[MEM_PHY_ADDR_W+2+GMEM_N_BANK_W-1:2+GMEM_N_BANK_W];
   assign awready = ~awaddr_fifo_full;
   assign awaddr_fifo_push = awvalid & awready;

   always_ff @(posedge clk) begin
      automatic logic pop_awaddr = '0;
      automatic int bid_wait_cycles = 0;
      if (!nrst) begin
         awaddr_fifo_wrAddr <= '0;
         awaddr_fifo_rdAddr <= '0;
         st_write <= get_address;
         awaddr_fifo_nempty <= '0;
         awaddr_fifo_full <= '0;
         awaddr_fifo_pop <= '0;
         awid_fifo_rdAddr <= '0;
         awid_fifo_wrAddr <= '0;
      end else begin
         wready <= '1;
         wdata_vec <= {wdata, wdata_vec[$high(wdata_vec):1]};
         wlast_vec[$high(wlast_vec)-1:0] <= wlast_vec[$high(wlast_vec):1];

         wlast_vec[$high(wlast_vec)] <= 'b0;
         if (wlast) begin
            while (1) begin
               bid_wait_cycles = $floor($itor($urandom()) * $itor(2**BVALID_DELAY_W) / $itor(32'hffffffff));
               if (bid_wait_cycles > 2**BVALID_DELAY_W-2) begin
                  bid_wait_cycles = 2**BVALID_DELAY_W-2;
               end
               if (wlast_vec[bid_wait_cycles+1] == 'b0) begin
                  wlast_vec[bid_wait_cycles] <= 'b1;
                  break;
               end else begin
               end
            end // while (1)
         end // if (wlast)

         wvalid_vec <= {wvalid, wvalid_vec[$high(wvalid_vec):1]};
         wstrb_vec <= {wstrb, wstrb_vec[$high(wstrb_vec):1]};
         wr_addr_offset_vec <= {wr_addr_offset, wr_addr_offset_vec[$high(wr_addr_offset_vec):1]};

         if (wlast_vec[0]) begin
            bvalid <= 'b1;
            tmp <= $unsigned(awid_fifo_rdAddr);
            bid <= awid_fifo[awid_fifo_rdAddr];
            awid_fifo_rdAddr <= awid_fifo_rdAddr + 1;
         end else if (bready) begin
            bvalid <= 'b0;
         end
         pop_awaddr = 0;
         awaddr_fifo_pop <= 'b0;
         case (st_write)
           get_address : begin
              if (awaddr_fifo_nempty) begin
                 awaddr_fifo_pop <= 'b1;
                 pop_awaddr = 'b1;
                 wr_addr <= awaddr_fifo[$unsigned(awaddr_fifo_rdAddr)] - ADDR_OFFSET;

                 awaddr_fifo_rdAddr <= awaddr_fifo_rdAddr + 1;
                 st_write <= write_data;
              end
           end
           write_data : begin
              if (wvalid && wready) begin
                 wr_addr <= wr_addr + 8;
                 if (wlast) begin
                    if (awaddr_fifo_nempty) begin
                       awaddr_fifo_pop <= 'b1;
                       pop_awaddr = 'b1;
                       wr_addr <= awaddr_fifo[$unsigned(awaddr_fifo_rdAddr)] - ADDR_OFFSET;
                       awaddr_fifo_rdAddr <= awaddr_fifo_rdAddr + 1;
                       st_write <= write_data;
                    end else begin
                       st_write <= get_address;
                    end
                 end
              end
           end
         endcase // case (st_write)
         if (awaddr_fifo_push) begin
            awaddr_fifo[$unsigned(awaddr_fifo_wrAddr)] <= $unsigned(awaddr);
            awaddr_fifo_wrAddr <= awaddr_fifo_wrAddr + 1;
            awid_fifo[$unsigned(awid_fifo_wrAddr)] <= awid;
            awid_fifo_wrAddr <= awid_fifo_wrAddr + 1;
         end

         if (awaddr_fifo_push && !pop_awaddr && awaddr_fifo_wrAddr+1 == awaddr_fifo_rdAddr) begin
            awaddr_fifo_full <= 'b1;
         end else if (!awaddr_fifo_push && pop_awaddr) begin
            awaddr_fifo_full <= 'b0;
         end
         if (awaddr_fifo_push && !pop_awaddr) begin
            awaddr_fifo_nempty <= 'b1;
         end else if (!awaddr_fifo_push && pop_awaddr && awaddr_fifo_rdAddr+1 == awaddr_fifo_wrAddr) begin
            awaddr_fifo_nempty <= 'b0;
         end
      end // else: !if(!nrst)
   end // always_ff @ (posedge clk)
   // }
endmodule
