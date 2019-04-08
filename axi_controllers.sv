`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module axi_controllers
  (
   // to tag controller {
   // axi read control
   input logic [GMEM_WORD_ADDR_W-N-1:0]    axi_rdAddr,
   input logic                             wr_fifo_go,
   output logic                            wr_fifo_free, // free ports have to respond to go ports immediately (in one clock cycle)
   // axi write control
   input logic [GMEM_WORD_ADDR_W-N-1:0]    axi_wrAddr,
   input logic                             axi_writer_go,
   output logic                            axi_writer_free = 'b0,
   output logic                            axi_writer_ack = 'b0, // high for just one clock cycle
   // }

   // to cache controller {
   output logic                            wr_fifo_cache_rqst, // gmem to cache request
   output logic                            rd_fifo_cache_rqst, // when write back request
   input logic                             wr_fifo_cache_ack, // gmem to cache ack
   input logic                             rd_fifo_cache_ack, // when write back ack
   output logic [M+L-1:0]                  wr_fifo_rqst_addr, // gmem to cache addr
   output logic [M+L-1:0]                  rd_fifo_rqst_addr, // when write back addr
   output logic [CACHE_N_BANKS*DATA_W-1:0] wr_fifo_dout,
   input logic [DATA_W*2**N-1:0]           cache_dob,
   input logic                             rd_fifo_din_v,
   // be signals
   input logic [DATA_W/8*2**N-1:0]         fifo_be_din,
   // }

   // axi signals {
   // read address channel
   output logic [GMEM_ADDR_W-1:0]          axi_araddr,
   output logic                            axi_arvalid,
   input logic                             axi_arready,
   output logic [ID_WIDTH-1:0]             axi_arid,
   // read data channel
   input logic [DATA_W*GMEM_N_BANK-1:0]    axi_rdata,
   input logic                             axi_rlast,
   input logic                             axi_rvalid,
   output logic                            axi_rready,
   input logic [ID_WIDTH-1:0]              axi_rid,
   // write address channel
   output logic [GMEM_ADDR_W-1:0]          axi_awaddr,
   output logic                            axi_awvalid,
   input logic                             axi_awready,
   output logic [ID_WIDTH-1:0]             axi_awid,
   // write data channel
   output logic [DATA_W*GMEM_N_BANK-1:0]   axi_wdata = '0,
   output logic                            axi_wvalid,
   output logic [DATA_W*GMEM_N_BANK/8-1:0] axi_wstrb = '0,
   output logic                            axi_wlast = '0,
   input logic                             axi_wready,
   // write response channel
   input logic                             axi_bvalid,
   output logic                            axi_bready,
   input logic [ID_WIDTH-1:0]              axi_bid,
   // }
   input logic                             clk,
   input logic                             nrst
   );

   logic                                   axi_arvalid_i = '0;
   logic                                   axi_rready_i = '0;
   logic                                   axi_awvalid_i = '0;
   logic                                   wr_fifo_free_i = 'b1;
   logic [GMEM_ADDR_W-1:0]                 axi_araddr_i = '0;
   logic [ID_WIDTH-1:0]                    axi_arid_i = '0;
   logic                                   rd_fifo_cache_rqst_i = '0;
   logic [M+L-1:0]                         wr_fifo_rqst_addr_i = '0;
   logic [M+L-1:0]                         rd_fifo_rqst_addr_i = '0;
   logic                                   axi_wvalid_i = '0;

   // axi interfaces {
   typedef enum {channel_idle, active} st_addr_channel;
   st_addr_channel st_ar = channel_idle;
   st_addr_channel st_ar_n = channel_idle;
   logic axi_arvalid_n = '0;
   logic axi_rready_n = '0;
   logic wr_fifo_free_n = '0;

   logic [GMEM_ADDR_W-1:0] axi_araddr_n = '0;
   logic                   axi_set_araddr_ack = '0;
   logic                   axi_set_araddr_ack_n = '0;
   logic [ID_WIDTH-1:0]    axi_arid_n = '0;
   logic                   axi_writer_free_n = '0;
   // }
   // a fifo can write (wr_fifo) the cache or can read (rd_fifo) from the cache
   // write fifos (read axi channels) {
   typedef enum            {wr_fifo_idle, send_address, get_data, wait_empty, wait_for_writing_cache, wait2} st_wr_fifo_type;
   st_wr_fifo_type st_wr_fifo = wr_fifo_idle;
   st_wr_fifo_type st_wr_fifo_n = wr_fifo_idle;
   logic [M+L-1:0]         wr_fifo_rqst_addr_n = '0;
   logic                   wr_fifo_push = '0;
   logic                   wr_fifo_push_n = '0;
   logic                   wr_fifo_set_araddr = '0;
   logic                   wr_fifo_set_araddr_n = '0;
   logic [BURST_W-1:0]     wr_fifo_wrAddr = '0;
   logic [BURST_W-1:0]     wr_fifo_wrAddr_n = '0;
   (* max_fanout = 60 *) logic [BURST_WORDS_W-CACHE_N_BANKS_W-1:0] wr_fifo_rdAddr = '0;
   logic [BURST_WORDS_W-CACHE_N_BANKS_W-1:0] wr_fifo_rdAddr_n = '0;
   logic                                     wr_fifo_full = '0;
   logic                                     wr_fifo_full_n = '0;
   logic [2**BURST_W-1:0][DATA_W*GMEM_N_BANK-1:0] wr_fifo = '0;
   logic [DATA_W*GMEM_N_BANK-1:0]                 axi_rdata_d0 = '0;
   logic [DATA_W*GMEM_N_BANK-1:0]                 axi_rdata_wr_fifo = '0;
   // }
   // read fifos (write axi channels) {
   logic [2**RD_FIFO_W-1:0][DATA_W*GMEM_N_BANK-1:0] rd_fifo = '0;
   logic                                            rd_fifo_cache_rqst_n = '0;
   logic [M+L-1:0]                                  rd_fifo_rqst_addr_n = '0;
   logic [DATA_W*GMEM_N_BANK-1:0]                   fifo_cache_rqst_rd_data = '0;
   logic                                            rd_fifo_pop = '0;
   logic                                            rd_fifo_slice_filled = '0;
   logic                                            axi_written = '0;

   typedef enum                                     {fifo_idle, fill_fifo, wait_w_channel} st_rd_fifo_fill_type;
   st_rd_fifo_fill_type st_rd_fifo_data = fifo_idle;
   st_rd_fifo_fill_type st_rd_fifo_data_n = fifo_idle;
   (* max_fanout = 60 *) logic unsigned [RD_FIFO_N_BURSTS_W+BURST_WORDS_W-CACHE_N_BANKS_W-1:0] rd_fifo_wrAddr = '0;
   logic unsigned [RD_FIFO_N_BURSTS_W+BURST_WORDS_W-CACHE_N_BANKS_W-1:0] rd_fifo_wrAddr_n = '0;
   logic unsigned [RD_FIFO_N_BURSTS_W+BURST_WORDS_W-GMEM_N_BANK_W-1:0]   rd_fifo_rdAddr = '0;
   logic unsigned [RD_FIFO_N_BURSTS_W+BURST_WORDS_W-GMEM_N_BANK_W-1:0]   rd_fifo_rdAddr_n = '0;
   logic                                                                 rd_fifo_nempty = '0;
   logic                                                                 rd_fifo_nempty_n = '0;
   logic [RD_FIFO_W-1:0]                                                 rd_fifo_n_filled = '0;
   logic [RD_FIFO_W-1:0]                                                 rd_fifo_n_filled_n = '0;
   logic [RD_FIFO_W-1:0]                                                 rd_fifo_n_filled_on_ack = '0;
   logic [RD_FIFO_W-1:0]                                                 rd_fifo_n_filled_on_ack_n = '0;
   logic [DATA_W*2**N-1:0]                                               cache_dob_latched = '0;
   logic                                                                 axi_wlast_p0 = '0;
   logic                                                                 rd_fifo_din_v_d0 = '0;
   logic [DATA_W*2**N-1:0]                                               cache_dob_d0 = '0;
   logic [DATA_W/8*2**N-1:0]                                             fifo_be_din_d0 = '0;
   // be fifos
   logic [2**RD_FIFO_W-1:0][GMEM_N_BANK*DATA_W/8-1:0]                    fifo_be = '0;
   logic [2**RD_FIFO_N_BURSTS_W-1:0][GMEM_ADDR_W-1:0]                    awaddr_fifo = '0;
   logic [RD_FIFO_N_BURSTS_W-1:0]                                        awaddr_fifo_wrAddr = '0;
   logic [RD_FIFO_N_BURSTS_W-1:0]                                        awaddr_fifo_wrAddr_n = '0;
   logic [RD_FIFO_N_BURSTS_W-1:0]                                        awaddr_fifo_rdAddr = '0;
   logic [RD_FIFO_N_BURSTS_W-1:0]                                        awaddr_fifo_rdAddr_n = '0;
   logic                                                                 awaddr_fifo_pop = '0;
   logic                                                                 awaddr_fifo_pop_n = '0;
   logic                                                                 awaddr_fifo_full = '0;
   logic                                                                 awaddr_fifo_full_n = '0;
   logic                                                                 awaddr_fifo_nempty = '0;
   logic                                                                 awaddr_fifo_nempty_n = '0;
   // }
   assign axi_arvalid = axi_arvalid_i;
   assign axi_wvalid = axi_wvalid_i;
   assign axi_rready = axi_rready_i;
   assign axi_awvalid = axi_awvalid_i;
   assign axi_bready = '1;
   assign wr_fifo_free = wr_fifo_free_i;
   assign rd_fifo_cache_rqst = rd_fifo_cache_rqst_i;
   assign wr_fifo_rqst_addr = wr_fifo_rqst_addr_i;
   assign rd_fifo_rqst_addr = rd_fifo_rqst_addr_i;
   assign axi_araddr = axi_araddr_i;
   assign axi_arid = axi_arid_i;

   // axi fifos wr (to cache) ----------------------------------------------------------------------------------------{
   // send data to cache when the fifo is full
   assign wr_fifo_cache_rqst = wr_fifo_full;

   always_ff @(posedge clk) begin
      if (wr_fifo_push) begin
         wr_fifo[$unsigned(wr_fifo_wrAddr)] <= axi_rdata_wr_fifo;
      end
      wr_fifo_push <= wr_fifo_push_n;
      wr_fifo_free_i <= wr_fifo_free_n;
      if (!nrst) begin
         st_wr_fifo <= wr_fifo_idle;
         wr_fifo_set_araddr <= '0;
         wr_fifo_rqst_addr_i <= '0;
      end else begin
         st_wr_fifo <= st_wr_fifo_n;
         wr_fifo_set_araddr <= wr_fifo_set_araddr_n;
         wr_fifo_rqst_addr_i <= wr_fifo_rqst_addr_n;
      end
   end

   always_comb begin
      st_wr_fifo_n <= st_wr_fifo;
      wr_fifo_set_araddr_n <= wr_fifo_set_araddr;
      wr_fifo_free_n <= wr_fifo_free_i;
      wr_fifo_rqst_addr_n <= wr_fifo_rqst_addr_i;

      if (wr_fifo_cache_ack || wr_fifo_rdAddr != '0) begin
         wr_fifo_rqst_addr_n <= wr_fifo_rqst_addr_i + 1;
      end
      wr_fifo_push_n <= 'b0;

      case (st_wr_fifo)
        wr_fifo_idle : begin
           wr_fifo_free_n <= 'b1;
           if (wr_fifo_go) begin // cache miss (from tag manager)
              wr_fifo_free_n <= 'b0;
              wr_fifo_set_araddr_n <= 'b1;
              st_wr_fifo_n <= send_address;
              wr_fifo_rqst_addr_n <= axi_rdAddr[M+L-1:0]; // this signal has priority on wr_fifo_cache_ack when setting wr_fifo_rqst_addr_n
           end
        end
        send_address : begin
           if (axi_set_araddr_ack) begin
              st_wr_fifo_n <= get_data;
              wr_fifo_set_araddr_n <= '0;
           end
        end
        get_data : begin
           if (axi_rvalid) begin
              wr_fifo_push_n <= 'b1;
              if (axi_rlast) begin
                 st_wr_fifo_n <= wait_empty;
              end
           end
        end
        wait_empty : begin
           if (wr_fifo_rdAddr == '1) begin
              wr_fifo_free_n <= 'b1;
              st_wr_fifo_n <= wr_fifo_idle;
           end
        end
        wait_for_writing_cache : begin
           wr_fifo_free_n <= 'b1;
           st_wr_fifo_n <= wr_fifo_idle;
        end
        wait2 : begin
           wr_fifo_free_n <= 'b1;
           st_wr_fifo_n <= wr_fifo_idle;
        end
      endcase
   end

   always_comb begin
      automatic int indx = 0;
      for (int j = 0; j < CACHE_N_BANKS/GMEM_N_BANK; j++) begin
         if (CACHE_N_BANKS_W > GMEM_N_BANK_W) begin
            indx[((CACHE_N_BANKS_W > GMEM_N_BANK_W) ? (CACHE_N_BANKS_W-GMEM_N_BANK_W-1):0):0] = j;
         end
         indx[$high(indx):CACHE_N_BANKS_W-GMEM_N_BANK_W] = wr_fifo_rdAddr;
         wr_fifo_dout[j*GMEM_DATA_W+:GMEM_DATA_W] <= wr_fifo[$unsigned(indx)];
      end
   end

   always_comb begin
      wr_fifo_rdAddr_n <= wr_fifo_rdAddr;
      wr_fifo_wrAddr_n <= wr_fifo_wrAddr;
      wr_fifo_full_n <= wr_fifo_full;
      if (wr_fifo_cache_ack || wr_fifo_rdAddr != '0) begin
         wr_fifo_rdAddr_n <= wr_fifo_rdAddr + 1;
      end
      if (wr_fifo_push) begin
         wr_fifo_wrAddr_n <= wr_fifo_wrAddr + 1;
      end
      if (wr_fifo_push && wr_fifo_wrAddr == '1) begin
         wr_fifo_full_n <= 'b1;
      end else if (wr_fifo_cache_ack) begin
         wr_fifo_full_n <= 'b0;
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         wr_fifo_wrAddr <= wr_fifo_wrAddr_n;
         wr_fifo_rdAddr <= wr_fifo_rdAddr_n;
         wr_fifo_full <= wr_fifo_full_n;
      end else begin
         wr_fifo_wrAddr <= '0;
         wr_fifo_rdAddr <= '0;
         wr_fifo_full <= '0;
      end
   end
   // }

   // axi read channels ------------------------------------------------------------------------------------------- {
   always_ff @(posedge clk) begin
      axi_set_araddr_ack <= axi_set_araddr_ack_n;
      cache_dob_d0 <= cache_dob;
      axi_arid_i <= axi_arid_n;
      rd_fifo_din_v_d0 <= rd_fifo_din_v;
      fifo_be_din_d0 <= fifo_be_din;
      if (nrst) begin
         axi_arvalid_i <= axi_arvalid_n;
         axi_rready_i <= axi_rready_n;
         axi_araddr_i <= axi_araddr_n;
         st_ar <= st_ar_n;
      end else begin
         axi_arvalid_i <= '0;
         axi_rready_i <= '0;
         axi_araddr_i <= '0;
         st_ar <= channel_idle;
      end
   end // always_ff @ (posedge clk)

   always_comb begin
      st_ar_n <= st_ar;
      axi_arvalid_n <= axi_arvalid_i;
      axi_araddr_n <= axi_araddr_i;
      axi_araddr_n[N+2-1:0] <= '0;
      axi_arid_n <= axi_arid_i;
      axi_set_araddr_ack_n <= 'b0;
      case (st_ar)
        channel_idle : begin
           if (wr_fifo_set_araddr) begin
              st_ar_n <= active;
              axi_arvalid_n <= 'b1;
              axi_araddr_n[GMEM_ADDR_W-1:N+2] <= axi_rdAddr;
              axi_set_araddr_ack_n <= 'b1;
           end
        end
        active : begin
           if (axi_arready) begin
              axi_arvalid_n <= 'b0;
              st_ar_n <= channel_idle;
           end
        end
      endcase
      axi_rready_n <= 'b1;
   end
   // }
   // axi fifos rd (from cache) ------------------------------------------------------------------------------------{
   always_ff @(posedge clk) begin
      if (axi_written || !rd_fifo_slice_filled) begin
         axi_wdata <= rd_fifo[$unsigned(rd_fifo_rdAddr)];
         axi_wstrb <= fifo_be[$unsigned(rd_fifo_rdAddr)];
         axi_wvalid_i <= rd_fifo_nempty;
         axi_wlast <= axi_wlast_p0;
      end
   end

   generate begin
      for (genvar i = 0; i < CACHE_N_BANKS/GMEM_N_BANK; i++) begin
         always_ff @(posedge clk) begin
            automatic logic unsigned [BURST_W+RD_FIFO_N_BURSTS_W-1:0] indx;
            indx[CACHE_N_BANKS_W-GMEM_N_BANK_W:0] = $unsigned(i);
            indx[$high(indx):CACHE_N_BANKS_W-GMEM_N_BANK_W] = rd_fifo_wrAddr;
            rd_fifo[$unsigned(indx)] <= cache_dob_d0[i*GMEM_DATA_W+:GMEM_DATA_W];
            fifo_be[$unsigned(indx)] <= fifo_be_din_d0[i*GMEM_DATA_W/8+:GMEM_DATA_W/8];
         end
      end end
   endgenerate

   always_ff @(posedge clk) begin
      rd_fifo_rqst_addr_i <= rd_fifo_rqst_addr_n;
      axi_writer_free <= axi_writer_free_n;
      rd_fifo_nempty <= rd_fifo_nempty_n;
      axi_writer_ack <= axi_bvalid;
      if (nrst) begin
         st_rd_fifo_data <= st_rd_fifo_data_n;
         rd_fifo_cache_rqst_i <= rd_fifo_cache_rqst_n;
         rd_fifo_rdAddr <= rd_fifo_rdAddr_n;
         rd_fifo_wrAddr <= rd_fifo_wrAddr_n;
         rd_fifo_n_filled <= rd_fifo_n_filled_n;
         rd_fifo_n_filled_on_ack <= rd_fifo_n_filled_on_ack_n;
         if (axi_written || !rd_fifo_slice_filled) begin
            axi_wlast_p0 <= 'b0;
            if (rd_fifo_rdAddr[BURST_W-1:1] == '1 &&
                rd_fifo_rdAddr[0] == '0 &&
                rd_fifo_pop) begin
               axi_wlast_p0 <= 'b1;
            end
         end
         if (axi_written && !rd_fifo_nempty) begin
            rd_fifo_slice_filled <= 'b0;
         end
         if (!rd_fifo_slice_filled && rd_fifo_nempty) begin
            rd_fifo_slice_filled <= 'b1;
         end
      end else begin
         st_rd_fifo_data <= fifo_idle;
         rd_fifo_cache_rqst_i <= '0;
         rd_fifo_rdAddr <= '0;
         rd_fifo_wrAddr <= '0;
         rd_fifo_n_filled <= '0;
         rd_fifo_n_filled_on_ack <= '0;
         axi_wlast_p0 <= '0;
         rd_fifo_slice_filled <= '0;
      end
   end

   always_comb begin
      rd_fifo_rdAddr_n <= rd_fifo_rdAddr;
      rd_fifo_wrAddr_n <= rd_fifo_wrAddr;
      if (rd_fifo_pop) begin
         rd_fifo_rdAddr_n <= rd_fifo_rdAddr + 1;
      end
      if (rd_fifo_din_v_d0) begin
         rd_fifo_wrAddr_n <= rd_fifo_wrAddr + 1;
      end

      if (!rd_fifo_pop && !rd_fifo_din_v_d0) begin
         rd_fifo_n_filled_n <= rd_fifo_n_filled;
      end else if (rd_fifo_pop && !rd_fifo_din_v_d0) begin
         rd_fifo_n_filled_n <= rd_fifo_n_filled - 1;
      end else if (rd_fifo_pop && rd_fifo_din_v_d0) begin
         rd_fifo_n_filled_n <= rd_fifo_n_filled - 1 + CACHE_N_BANKS/GMEM_N_BANK;
      end else begin
         rd_fifo_n_filled_n <= rd_fifo_n_filled + CACHE_N_BANKS/GMEM_N_BANK;
      end
      // consider the rd_fifo_cache_ack as the push signal for not overfilling the fifo
      if (!rd_fifo_pop && !rd_fifo_cache_ack) begin
         rd_fifo_n_filled_on_ack_n <= rd_fifo_n_filled_on_ack;
      end else if (rd_fifo_pop && !rd_fifo_cache_ack) begin
         rd_fifo_n_filled_on_ack_n <= rd_fifo_n_filled_on_ack - 1;
      end else if (rd_fifo_pop && rd_fifo_cache_ack) begin
         rd_fifo_n_filled_on_ack_n <= rd_fifo_n_filled_on_ack - 1 + (2**BURST_WORDS_W)/GMEM_N_BANK;
      end else begin
         rd_fifo_n_filled_on_ack_n <= rd_fifo_n_filled_on_ack + (2**BURST_WORDS_W)/GMEM_N_BANK;
      end
   end // always_comb

   always_comb begin
      if (rd_fifo_n_filled_n == '0) begin
         rd_fifo_nempty_n <= 'b0;
      end else begin
         rd_fifo_nempty_n <= 'b1;
      end
      axi_written <= axi_wready & axi_wvalid_i;
      rd_fifo_pop <= rd_fifo_nempty & (axi_written | (~rd_fifo_slice_filled));
   end

   always_comb begin
      st_rd_fifo_data_n <= st_rd_fifo_data;
      rd_fifo_rqst_addr_n <= rd_fifo_rqst_addr_i;
      rd_fifo_cache_rqst_n <= rd_fifo_cache_rqst_i;
      axi_writer_free_n <= ~awaddr_fifo_full;
      case (st_rd_fifo_data)
        fifo_idle : begin
           if (axi_writer_go) begin
              st_rd_fifo_data_n <= fill_fifo;
              rd_fifo_rqst_addr_n <= axi_wrAddr[M+L-1:0];
              rd_fifo_cache_rqst_n <= 'b1;
              axi_writer_free_n <= 'b0;
           end
        end
        fill_fifo : begin
           axi_writer_free_n <= 'b0;
           if (rd_fifo_cache_ack) begin
              rd_fifo_cache_rqst_n <= '0;
              if (rd_fifo_n_filled_on_ack_n[$high(rd_fifo_n_filled_on_ack_n):BURST_W] != '1) begin
                 axi_writer_free_n <= ~awaddr_fifo_full;
                 st_rd_fifo_data_n <= fifo_idle;
              end else begin
                 st_rd_fifo_data_n <= wait_w_channel;
              end
           end
        end
        wait_w_channel : begin
           axi_writer_free_n <= 'b0;
           if (rd_fifo_n_filled_on_ack_n[$high(rd_fifo_n_filled_on_ack_n):BURST_W] != '1) begin
              axi_writer_free_n <= ~awaddr_fifo_full;
              st_rd_fifo_data_n <= fifo_idle;
           end
        end
      endcase
   end
   // }

   // awaddr fifo {
   always_ff @(posedge clk) begin
      if (axi_writer_go) begin
         awaddr_fifo[$unsigned(awaddr_fifo_wrAddr)][GMEM_ADDR_W-1:N+2] <= axi_wrAddr;
         awaddr_fifo[$unsigned(awaddr_fifo_wrAddr)][N+2-1:0] <= '0;
      end

      axi_rdata_wr_fifo <= axi_rdata;

      if (nrst) begin
         awaddr_fifo_nempty <= awaddr_fifo_nempty_n;
         awaddr_fifo_full <= awaddr_fifo_full_n;
         awaddr_fifo_wrAddr <= awaddr_fifo_wrAddr_n;
         awaddr_fifo_rdAddr <= awaddr_fifo_rdAddr_n;
      end else begin
         awaddr_fifo_wrAddr <= '0;
         awaddr_fifo_rdAddr <= '0;
         awaddr_fifo_full <= '0;
         awaddr_fifo_nempty <= '0;
      end
   end

   always_comb begin
      axi_awaddr <= awaddr_fifo[$unsigned(awaddr_fifo_rdAddr)];
      axi_awid <= 'b0;
   end

   always_comb begin
      awaddr_fifo_wrAddr_n <= awaddr_fifo_wrAddr;
      awaddr_fifo_rdAddr_n <= awaddr_fifo_rdAddr;
      if (axi_writer_go) begin
         awaddr_fifo_wrAddr_n <= awaddr_fifo_wrAddr + 1;
      end
      if (axi_awvalid_i && axi_awready) begin
         awaddr_fifo_rdAddr_n <= awaddr_fifo_rdAddr + 1;
      end
      axi_awvalid_i <= awaddr_fifo_nempty;
   end // always_comb

   always_comb begin
      awaddr_fifo_full_n <= awaddr_fifo_full;
      awaddr_fifo_nempty_n <= awaddr_fifo_nempty;
      if (axi_writer_go && (!axi_awvalid_i || !axi_awready) && awaddr_fifo_wrAddr_n == awaddr_fifo_rdAddr) begin
         awaddr_fifo_full_n <= 'b1;
      end else if (!axi_writer_go && axi_awvalid_i && axi_awready) begin
         awaddr_fifo_full_n <= 'b0;
      end
      if (axi_writer_go && (!axi_awvalid_i || !axi_awready)) begin
         awaddr_fifo_nempty_n <= 'b1;
      end else if (!axi_writer_go && axi_awvalid_i && axi_awready && awaddr_fifo_wrAddr == awaddr_fifo_rdAddr_n) begin
         awaddr_fifo_nempty_n <= 'b0;
      end
   end
   // }

endmodule
