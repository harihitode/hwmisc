`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module gmem_cntrl
  (
   input logic                                         clk,
   input logic                                         start_kernel,
   input logic                                         clean_cache,
   input logic                                         WGsDispatched,
   input logic                                         CUs_gmem_idle,
   output logic                                        finish_exec,

   input logic                                         cu_valid,
   output logic                                        cu_ready,
   input logic [DATA_W/8-1:0]                          cu_we,
   input logic                                         cu_rnw, // cu read (or 0 for write)
   input logic                                         cu_atomic,
   input logic [N_CU_STATIONS_W-1:0]                   cu_atomic_sgntr,
   input logic [GMEM_WORD_ADDR_W-1:0]                  cu_rqst_addr,
   input logic [DATA_W-1:0]                            cu_wrData,
   output logic                                        rdAck = 'b0,
   output logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] rdAddr = 'b0,
   output wire [DATA_W*CACHE_N_BANKS-1:0]              rdData,
   output logic [DATA_W-1:0]                           atomic_rdData = 'b0, // for dest register of atomic inst
   output logic                                        atomic_rdData_v = 'b0,
   output logic [N_CU_STATIONS_W-1:0]                  atomic_sgntr = 'b0,
   // Control Interface - AXI LITE SLAVE
   // Read Address Channel
   output logic [GMEM_ADDR_W-1:0]                      axi_araddr,
   output logic                                        axi_arvalid,
   input logic                                         axi_arready,
   output logic [ID_WIDTH-1:0]                         axi_arid,
   // Read Data Channel
   input logic [DATA_W*GMEM_N_BANK-1:0]                axi_rdata,
   input logic                                         axi_rlast,
   input logic                                         axi_rvalid,
   output logic                                        axi_rready,
   input logic [ID_WIDTH-1:0]                          axi_rid,
   // Write Address Channel
   output logic [GMEM_ADDR_W-1:0]                      axi_awaddr,
   output logic                                        axi_awvalid,
   input logic                                         axi_awready,
   output logic [ID_WIDTH-1:0]                         axi_awid,
   // Write Data Channel
   output logic [DATA_W*GMEM_N_BANK-1:0]               axi_wdata,
   output logic [DATA_W*GMEM_N_BANK/8-1:0]             axi_wstrb,
   output logic                                        axi_wlast,
   output logic                                        axi_wvalid,
   input logic                                         axi_wready,
   // Write Response Channel
   input logic                                         axi_bvalid,
   output logic                                        axi_bready,
   input logic [ID_WIDTH-1:0]                          axi_bid,

   input logic                                         nrst
   );

   logic                                               cu_ready_i = 'b0;
   wire                                                axi_wvalid_i;
   wire [DATA_W*CACHE_N_BANKS-1:0]                     rdData_i;
   wire                                                finish_exec_i;
   // axi signals
   wire [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0]         axi_rdAddr;
   wire [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0]         axi_wrAddr;
   wire                                                wr_fifo_go;
   wire                                                axi_writer_go;
   wire                                                wr_fifo_free;
   wire                                                axi_writer_free;
   wire                                                axi_writer_ack;

   // TAG should be identical in all instances of request memory blocks
   // cnt is the number of set bits either in re or we. It's limited in bit width and needs to sturated while incrementing.

   int                                                C_RCV_CU_INDX [N_RECEIVERS-1:0] = '{default:'0};
   int                                                C_RCV_BANK_INDX [N_RECEIVERS-1:0] = '{default:'0};

   // CUs' interface {
   logic                                              cu_ready_n = 'b0;
   logic                                              cuIndx_msb = '0;
   logic                                              cu_atomic_ack_p0 = 'b0;
   // }
   // receivers signals {
   typedef enum     {get_addr, get_read_tag_ticket, wait_read_tag, check_tag_rd, check_tag_wr, alloc_tag, clean, request_write_addr, request_write_data, write_cache, read_cache, requesting_atomic} st_rcv_type;

   st_rcv_type st_rcv [N_RECEIVERS-1:0] = '{default:get_addr};
   st_rcv_type st_rcv_n [N_RECEIVERS-1:0] = '{default:get_addr};
   logic [N_RECEIVERS-1:0] rcv_idle = '0;
   logic [N_RECEIVERS-1:0] rcv_idle_n = '0;
   logic                   rcv_all_idle = '0;
   logic [N_RECEIVERS-1:0][GMEM_WORD_ADDR_W-1:0] rcv_gmem_addr = '0;
   logic [N_RECEIVERS-1:0][GMEM_WORD_ADDR_W-1:0] rcv_gmem_addr_n = '0;
   logic [N_RECEIVERS-1:0][DATA_W-1:0]           rcv_gmem_data = '0;
   logic [N_RECEIVERS-1:0][DATA_W-1:0]           rcv_gmem_data_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_rnw = '0;
   logic [N_RECEIVERS-1:0]                       rcv_rnw_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_atomic = '0;
   logic [N_RECEIVERS-1:0]                       rcv_atomic_n = '0;
   logic [N_RECEIVERS-1:0][(DATA_W/8-1):0]       rcv_be = '0;
   logic [N_RECEIVERS-1:0][(DATA_W/8-1):0]       rcv_be_n = '0;
   logic [N_RECEIVERS-1:0][N_CU_STATIONS_W-1:0]  rcv_atomic_sgntr = '0;
   logic [N_RECEIVERS-1:0][N_CU_STATIONS_W-1:0]  rcv_atomic_sgntr_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_go = '0;
   logic [N_RECEIVERS-1:0]                       rcv_go_n = '0;
   wire [N_RECEIVERS-1:0]                        rcv_must_read;
   logic [N_RECEIVERS-1:0]                       rcv_read_tag = '0;
   logic [N_RECEIVERS-1:0]                       rcv_read_tag_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_atomic_rqst = '0;
   logic [N_RECEIVERS-1:0]                       rcv_atomic_rqst_n = '0;
   wire [N_RECEIVERS-1:0]                        rcv_atomic_ack;
   wire [N_RECEIVERS-1:0]                        rcv_atomic_performed;
   logic [N_CU_STATIONS_W-1:0]                   atomic_sgntr_p0 = '0;
   wire [N_RECEIVERS-1:0][(DATA_W/8)-1:0]        rcv_atomic_type;
   wire [N_RECEIVERS-1:0]                        rcv_read_tag_ack;
   logic [N_RECEIVERS-1:0]                       rcv_alloc_tag = '0;
   logic [N_RECEIVERS-1:0]                       rcv_alloc_tag_n = '0;
   logic [GMEM_WORD_ADDR_W-1:0]                  cu_rqst_addr_d0 = 'b0;
   logic [DATA_W-1:0]                            cu_wrData_d0 = 'b0;;
   logic                                         cu_rnw_d0 = 'b0;
   logic                                         cu_atomic_d0 = 'b0;
   logic [(DATA_W/8)-1:0]                        cu_we_d0 = 'b0;
   logic [N_CU_STATIONS_W-1:0]                   cu_atomic_sgntr_d0 = 'b0;
   wire [N_RECEIVERS-1:0]                        rcv_tag_written;
   wire [N_RECEIVERS-1:0]                        rcv_tag_updated;
   wire [N_RECEIVERS-1:0]                        rcv_page_validated;
   logic [N_RECEIVERS-1:0]                       rcv_perform_read = '0;
   logic [N_RECEIVERS-1:0]                       rcv_perform_read_n = '0;
   (* max_fanout = 50 *) logic [N_RECEIVERS-1:0] rcv_request_write_addr = '0;
   logic [N_RECEIVERS-1:0]                       rcv_request_write_addr_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_request_write_data = '0;
   logic [N_RECEIVERS-1:0]                       rcv_request_write_data_n = '0;
   logic [N_RECEIVERS-1:0]                       rcv_tag_compared = '0;
   logic [N_RECEIVERS-1:0]                       rcv_wait_1st_cycle = '0;
   logic [N_RECEIVERS-1:0]                       rcv_wait_1st_cycle_n = '0;
   // }
   // tag signals {
   wire [N_RD_PORTS-1:0][TAG_W-1:0]              rdData_tag;
   wire [N_RD_PORTS-1:0]                         rdData_tag_v;
   wire [N_RD_PORTS-1:0]                         rdData_page_v;
   logic [N_RD_PORTS-1:0]                        rdData_page_v_d0 = '0;
   // }
   // cache signals {
   logic [(2**N)*DATA_W/8-1:0]                   cache_wea = '0;
   logic [(2**N)*DATA_W/8-1:0]                   cache_wea_n = '0;
   logic                                         cache_we = '0;
   logic                                         cache_we_n = '0;
   logic unsigned [M+L-1:0]                      cache_addra = '0;
   logic unsigned [M+L-1:0]                      cache_addra_n = '0;
   (* max_fanout = 100 *) logic                  cache_read_v = '0;
   logic                                         cache_read_v_p0 = '0;
   logic [N_RECEIVERS-1:0]                       rcv_rd_done = '0;
   logic [N_RECEIVERS-1:0]                       rcv_rd_done_n = '0;
   logic                                         cache_read_v_p0_n = '0;
   logic                                         cache_read_v_d0 = '0;
   logic unsigned [M+L-1:0]                      cache_last_rdAddr = '0;
   // }
   // responder signals {
   logic [N_RECEIVERS_W-1:0]                     rcv_to_read = '0;
   logic [N_RECEIVERS_W-1:0]                     rcv_to_read_n = '0;
   logic unsigned [GMEM_WORD_ADDR_W-N-1:0]       rdAddr_p0 = '0;
   logic unsigned [GMEM_WORD_ADDR_W-N-1:0]       rdAddr_p1 = '0;
   logic [(2**N)*DATA_W-1:0]                     cache_wrData = '0;
   logic [N_RECEIVERS-1:0][RCV_PRIORITY_W-1:0]   rcv_priority = '0;
   logic [N_RECEIVERS-1:0][RCV_PRIORITY_W-1:0]   rcv_priority_n = '0;
   parameter C_SERVED_VEC_LEN = 2; // max(CACHE_N_BANKS-1, 2)
   logic [C_SERVED_VEC_LEN-1:0]                  cu_served = 'b0;
   (* max_fanout = 8 *) logic unsigned [WRITE_PHASE_W-1:0]            write_phase = '0;
   logic                                         cu_served_n = 'b0;
   localparam C_N_PRIORITY_CLASSES_W = 2;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0][N_RECEIVERS_W-1:0] rcv_to_read_pri = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0][N_RECEIVERS_W-1:0] rcv_to_read_pri_n = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0][N_RECEIVERS_W-1:0] rcv_to_write_pri = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0][N_RECEIVERS_W-1:0] rcv_to_write_pri_n = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0]                    rcv_to_read_pri_v = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0]                    rcv_to_read_pri_v_n = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0]                    rcv_to_write_pri_v = '0;
   logic [2**C_N_PRIORITY_CLASSES_W-1:0]                    rcv_to_write_pri_v_n = '0;
   // }
   // write pipeline {
   (* max_fanout = 60 *) logic [N_RECEIVERS_W-1:0] rcv_to_write = '0;
   logic [N_RECEIVERS_W-1:0]                                rcv_to_write_n;
   logic [N_RECEIVERS-1:0]                                  rcv_write_in_pipeline = '0;
   logic [N_RECEIVERS-1:0]                                  rcv_write_in_pipeline_n = '0;
   logic unsigned [3:0][M+L-1:0]                            write_addr = '0;
   logic [N_RECEIVERS-1:0]                                  rcv_will_write = '0;
   logic [N_RECEIVERS-1:0]                                  rcv_will_write_n = '0;
   logic [N_RECEIVERS-1:0]                                  rcv_will_write_d0 = '0;
   logic [DATA_W*2**N-1:0]                                  write_word = '0;
   logic [DATA_W/8*2**N-1:0][N_RECEIVERS_W-1:0]             write_word_rcv_indx = '0;
   logic [DATA_W/8*2**N-1:0][N_RECEIVERS_W-1:0]             write_word_rcv_indx_n = '0;
   logic [DATA_W/8*2**N-1:0]                                write_be_p0 = '0;
   logic [DATA_W/8*2**N-1:0]                                write_be_p0_n = '0;
   logic                                                    stall_write_pipe = '0;
   logic [3:0]                                              write_v = '0;
   logic [3:0]                                              write_v_n = '0;
   logic [DATA_W/8*2**N-1:0]                                write_be = '0;
   logic [4:0][M-1:0]                                       write_pipe_wrTag = '0;
   logic [4:0]                                              write_pipe_wrTag_valid = '0;
   logic [N_RECEIVERS-1:0]                                  write_addr_match = '0;
   logic [N_RECEIVERS-1:0]                                  write_addr_match_n = '0;
   // }
   // fifo {
   wire                                                     wr_fifo_cache_rqst;
   wire                                                     rd_fifo_cache_rqst;
   wire                                                     wr_fifo_cache_ack;
   wire                                                     rd_fifo_cache_ack;
   wire [M+L-1:0]                                           wr_fifo_rqst_addr;
   wire [M+L-1:0]                                           rd_fifo_rqst_addr;
   wire [CACHE_N_BANKS*DATA_W-1:0]                          wr_fifo_dout;
   wire [DATA_W*2**N-1:0]                                   cache_dob;
   wire                                                     rd_fifo_din_v;
   wire [DATA_W/8*2**N-1:0]                                 fifo_be_din;
   // }
   // atomic {
   logic                                                    flush_ack = '0;
   logic                                                    flush_ack_n = '0;
   logic                                                    flush_done = '0;
   logic [N_RECEIVERS_W-1:0]                                flush_rcv_index = '0;
   logic [N_RECEIVERS_W-1:0]                                flush_rcv_index_n = '0;
   wire                                                     flush_v;
   wire unsigned [GMEM_WORD_ADDR_W-1:0]                     flush_gmem_addr;
   wire [DATA_W-1:0]                                        flush_data;
   wire                                                     atomic_can_finish;
   // }

   // internal & fixed signals assignments {
   assign cu_ready = cu_ready_i;
   assign axi_wvalid = axi_wvalid_i;
   assign rdData = rdData_i;
   assign finish_exec = finish_exec_i;
   assign rcv_atomic_type = rcv_be;
   // }

   // cache {
   cache cache_inst
     (
      .clk(clk),
      .nrst(nrst),
      .ena(1'b1),
      .wea(cache_wea),
      .addra(cache_addra),
      .dia(cache_wrData),
      .doa(rdData_i),

      .enb(1'b1),
      .wr_fifo_rqst_addr(wr_fifo_rqst_addr),
      .rd_fifo_rqst_addr(rd_fifo_rqst_addr),
      .wr_fifo_dout(wr_fifo_dout),
      .dob(cache_dob),
      .rd_fifo_din_v(rd_fifo_din_v),
      .be_rdData(fifo_be_din),

      .ticket_rqst_wr(wr_fifo_cache_rqst),
      .ticket_rqst_rd(rd_fifo_cache_rqst),
      .ticket_ack_wr_fifo(wr_fifo_cache_ack),
      .ticket_ack_rd_fifo(rd_fifo_cache_ack)
      );

   // }

   // write pipeline {
   always_ff @(posedge clk) begin
      write_phase <= write_phase + 1;
      rcv_to_write_pri <= rcv_to_write_pri_n;
      rcv_to_write_pri_v <= rcv_to_write_pri_v_n;

      if (!stall_write_pipe || !write_v[2] || !write_v[1] || !write_v[0]) begin
         rcv_to_write <= rcv_to_write_n;
         write_v[0] <= write_v_n;
         rcv_write_in_pipeline <= rcv_write_in_pipeline_n;
      end

      if (!stall_write_pipe || !write_v[2] || !write_v[1]) begin
         write_addr[1] <= write_addr[0];
         write_v[1] <= write_v[0];
         write_addr_match <= write_addr_match_n;
      end

      if (!stall_write_pipe || !write_v[2]) begin
         rcv_will_write <= rcv_will_write_n;
         write_word_rcv_indx <= write_word_rcv_indx_n;
         write_be_p0 <= write_be_p0_n;
         write_addr[2] <= write_addr[1];
         write_v[2] <= write_v[1];
      end

      if (!stall_write_pipe) begin
         rcv_will_write_d0 <= rcv_will_write;
         write_addr[3] <= write_addr[2];
         write_be <= '0;
         write_v[3] <= write_v[2];
         write_be <= write_be_p0;
         for (int k = 0; k < DATA_W/8; k++) begin
            for (int j = 0; j < 2**N; j++) begin
               write_word[j*DATA_W+k*8+:8] <= rcv_gmem_data[write_word_rcv_indx[j*DATA_W/8+k]][8*k+:8];
            end
         end
      end
   end // always_ff @ (posedge clk)
   always_comb begin
      automatic logic unsigned [N_RECEIVERS_W-1:0] indx = '0;
      indx[N_RECEIVERS_W-1:N_RECEIVERS_W-WRITE_PHASE_W] = write_phase;
      for (int j = 0; j < 2**C_N_PRIORITY_CLASSES_W; j++) begin
         rcv_to_write_pri_n[j] <= 0;
         rcv_to_write_pri_v_n[j] <= '0;
         for (int i = 0; i < N_RECEIVERS/2**WRITE_PHASE_W; i++) begin
            indx[N_RECEIVERS_W-WRITE_PHASE_W-1:0] = i;
            if (rcv_request_write_addr[$unsigned(indx)] &&
                $unsigned(rcv_priority[$unsigned(indx)][RCV_PRIORITY_W-1:RCV_PRIORITY_W-C_N_PRIORITY_CLASSES_W]) == j) begin
               rcv_to_write_pri_n[j] <= $unsigned(indx);
               rcv_to_write_pri_v_n[j] <= 'b1;
            end
         end
      end
   end // always_comb
   always_comb begin
      automatic logic unsigned [N_RECEIVERS_W-1:0] rcv_indx = '0;
      rcv_to_write_n <= rcv_to_write;
      write_v_n <= '0;
      rcv_write_in_pipeline_n <= '0;
      // stage 0: define the rcv indx to write
      for (int j = 2**C_N_PRIORITY_CLASSES_W-1; j >= 0; j--) begin
         if (rcv_to_write_pri_v[j] == 'b1 && rcv_request_write_addr[rcv_to_write_pri[j]]) begin
            rcv_to_write_n <= rcv_to_write_pri[j];
            write_v_n <= 'b1;
            rcv_write_in_pipeline_n[rcv_to_write_pri[j]] <= 'b1;
            break;
         end
      end

      // stage 1: define the address to be written
      write_addr[0] <= rcv_gmem_addr[rcv_to_write][M+L+N-1:N];
      write_addr_match_n <= 'b0;
      for (int i = 0; i < N_RECEIVERS; i++) begin
         if (rcv_gmem_addr[i][M+L+N-1:N] == rcv_gmem_addr[rcv_to_write][M+L+N-1:N] && rcv_request_write_data[i]) begin
            write_addr_match_n[i] <= 'b1;
         end
      end

      // stage 2: define which receivers will write
      rcv_will_write_n = '0;
      write_word_rcv_indx_n = '0;
      write_be_p0_n = '0;
      if (write_v[1]) begin
         for (int k = 0; k < DATA_W/8; k++) begin
            for (int j = 0; j < 2**N; j++) begin
               for (int i = 0; i < N_RECEIVERS; i++) begin
                  if (write_addr_match[i] &&
                      $unsigned(rcv_gmem_addr[i][N-1:0]) == j &&
                      rcv_be[i][k] &&
                      rcv_request_write_data[i]) begin
                     rcv_will_write_n[i] <= 'b1;
                     write_word_rcv_indx_n[j*DATA_W/8+k] <= i;
                     write_be_p0_n[j*DATA_W/8+k] <= 'b1;
                  end
               end
            end
         end
      end // if (write_v[1])
      // stage 3: form the data word to be written
   end
   // }
   // responder {
   always_comb begin
      for (int i = 0; i < N_RECEIVERS; i++) begin
         for (int j = 0; j < 2**C_N_PRIORITY_CLASSES_W; j++) begin
            if (rcv_perform_read[i] &&
                $unsigned(rcv_priority[i][RCV_PRIORITY_W-1:RCV_PRIORITY_W-C_N_PRIORITY_CLASSES_W]) == j &&
                cu_served[C_RCV_CU_INDX[i]] == '0) begin
               rcv_to_read_pri_n[j] <= i;
               rcv_to_read_pri_v_n[j] <= 'b1;
            end
         end
      end
   end

   always_comb begin
      rcv_to_read_n <= rcv_to_read;
      cache_read_v_p0_n <= '0;
      cu_served_n <= 'b0;
      for (int j = 0; j < 2**C_N_PRIORITY_CLASSES_W; j++) begin
         if (rcv_to_read_pri_v[j] && rcv_perform_read[rcv_to_read_pri[j]]) begin
            rcv_to_read_n <= rcv_to_read_pri_n[j];
            cache_read_v_p0_n <= 'b1;
            cu_served_n <= 'b1;
            break;
         end
      end
   end

   always_ff @(posedge clk) begin
      automatic logic [N_RECEIVERS_W-1:0] rcv_indx = '0;

      cu_served[C_SERVED_VEC_LEN-2:0] <= cu_served[C_SERVED_VEC_LEN-1:1];
      cu_served[C_SERVED_VEC_LEN-1:0] <= cu_served_n;

      rcv_to_read_pri_v <= rcv_to_read_pri_v_n;
      cache_read_v_p0 <= '0;
      cache_wea <= cache_wea_n;
      cache_we <= cache_we_n;
      // stage 0 (read)

      // stage 1 (read)
      cache_addra <= cache_addra_n;
      rdAddr_p1 <= rcv_gmem_addr[rcv_to_read][GMEM_WORD_ADDR_W-1:N];

      // stage 1 (write)
      cache_wrData <= write_word;

      // stage 2 (write)
      rdAddr_p0 <= rdAddr_p1;
      rcv_rd_done <= rcv_rd_done_n;

      // stage 3 (write)
      rdAddr <= rdAddr_p0;
      rdAck <= |rcv_rd_done;

      if (nrst) begin
         // stage 0 (read)
         rcv_to_read_pri <= rcv_to_read_pri_n;
         rcv_to_read <= rcv_to_read_n;
         cache_read_v_p0 <= cache_read_v_p0_n;

         // stage 1 (read)
         cache_read_v <= cache_read_v_p0;

         // stage 1 (write)
         // stage 2
         cache_read_v_d0 <= cache_read_v;
      end else begin
         rcv_to_read_pri <= '0;
         rcv_to_read <= 0;
         cache_read_v_p0 <= '0;
         cache_read_v_d0 <= '0;
         cache_read_v <= '0;
      end
   end

   always_comb begin
      if (cache_read_v_p0) begin
         cache_addra_n <= rcv_gmem_addr[rcv_to_read][M+L+N-1:N];
      end else begin
         cache_addra_n <= write_addr[3];
      end
      if (!write_v[3] || !cache_read_v_p0) begin
         stall_write_pipe <= 'b0;
      end else begin
         stall_write_pipe <= 'b1;
      end
      cache_wea_n <= '0;
      cache_we_n <= 'b0;
      if (write_v[3] && !cache_read_v_p0) begin
         cache_wea_n <= write_be;
         cache_we_n <= 'b1;
      end
   end
   // }

   // axi controllers {
   axi_controllers axi_cntrl
     (
      .clk(clk),
      .axi_rdAddr(axi_rdAddr),
      .axi_wrAddr(axi_wrAddr),
      .wr_fifo_go(wr_fifo_go),
      .axi_writer_go(axi_writer_go),
      .axi_writer_ack(axi_writer_ack),
      .wr_fifo_free(wr_fifo_free),
      .axi_writer_free(axi_writer_free),
      .wr_fifo_cache_rqst(wr_fifo_cache_rqst),
      .rd_fifo_cache_rqst(rd_fifo_cache_rqst),
      .wr_fifo_cache_ack(wr_fifo_cache_ack),
      .rd_fifo_cache_ack(rd_fifo_cache_ack),
      .wr_fifo_rqst_addr(wr_fifo_rqst_addr),
      .rd_fifo_rqst_addr(rd_fifo_rqst_addr),
      .wr_fifo_dout(wr_fifo_dout),
      .cache_dob(cache_dob),
      .rd_fifo_din_v(rd_fifo_din_v),
      .fifo_be_din(fifo_be_din),

      .axi_araddr(axi_araddr),
      .axi_arvalid(axi_arvalid),
      .axi_arready(axi_arready),
      .axi_arid(axi_arid),
      .axi_rdata(axi_rdata),
      .axi_rlast(axi_rlast),
      .axi_rvalid(axi_rvalid),
      .axi_rready(axi_rready),
      .axi_rid(axi_rid),
      .axi_awaddr(axi_awaddr),
      .axi_awvalid(axi_awvalid),
      .axi_awready(axi_awready),
      .axi_awid(axi_awid),
      .axi_wdata(axi_wdata),
      .axi_wstrb(axi_wstrb),
      .axi_wlast(axi_wlast),
      .axi_wvalid(axi_wvalid_i),
      .axi_wready(axi_wready),
      .axi_bvalid(axi_bvalid),
      .axi_bready(axi_bready),
      .axi_bid(axi_bid),
      .nrst(nrst)
      );
   // }
   // tags mem {
   always_comb begin
      for (int i = 0; i < 4; i++) begin
         write_pipe_wrTag[i] <= write_addr[i][M+L-1:L];
         write_pipe_wrTag_valid[i] <= write_v[i];
      end
      write_pipe_wrTag[4] <= cache_addra[M+L-1:L];
      write_pipe_wrTag_valid[4] <= cache_we;
   end
   cache_tag tags_controller
     (
      .clk(clk),
      .wr_fifo_go(wr_fifo_go),
      .axi_writer_go(axi_writer_go),
      .axi_writer_ack(axi_writer_ack),
      .wr_fifo_free(wr_fifo_free),
      .axi_writer_free(axi_writer_free),
      .axi_rd_fifo_filled(rd_fifo_cache_ack),
      .axi_rdAddr(axi_rdAddr),
      .axi_wrAddr(axi_wrAddr),
      .wr_fifo_cache_ack(wr_fifo_cache_ack),
      .axi_wvalid(axi_wvalid_i),

      // receivers signals
      .rcv_alloc_tag(rcv_alloc_tag),
      .rcv_rnw(rcv_rnw),
      .rcv_gmem_addr(rcv_gmem_addr),

      .rcv_read_tag(rcv_read_tag),
      .rcv_read_tag_ack(rcv_read_tag_ack),

      .rdData_page_v(rdData_page_v),
      .rdData_tag_v(rdData_tag_v),
      .rdData_tag(rdData_tag),

      .rcv_tag_written(rcv_tag_written),
      .rcv_tag_updated(rcv_tag_updated),
      .rcv_page_validated(rcv_page_validated), // it is a one-cycle message

      .cache_we(cache_we),
      .cache_addra(cache_addra),
      .cache_wea(cache_wea),

      // finish
      .WGsDispatched(WGsDispatched),
      .CUs_gmem_idle(CUs_gmem_idle),
      .rcv_all_idle(rcv_all_idle),
      .rcv_idle(rcv_idle),
      .finish_exec(finish_exec_i),
      .start_kernel(start_kernel),
      .clean_cache(clean_cache),
      .atomic_can_finish(atomic_can_finish),

      // write pipeline
      .write_pipe_active(write_pipe_wrTag_valid),
      .write_pipe_wrTag(write_pipe_wrTag),

      .nrst(nrst)
      );
   // }

   // atomic {
   gmem_atomics atomic_inst
     (
      .clk(clk),
      .rcv_atomic_rqst(rcv_atomic_rqst),
      .rcv_atomic_ack(rcv_atomic_ack),
      .rcv_atomic_type(rcv_atomic_type),
      .rcv_gmem_addr(rcv_gmem_addr),
      .rcv_must_read(rcv_must_read),
      .rcv_gmem_data(rcv_gmem_data),
      .gmem_rdAddr_p0(rdAddr_p0),
      .gmem_rdData(rdData_i),
      .gmem_rdData_v_p0(cache_read_v_d0),
      .rcv_retire(rcv_atomic_performed),
      .atomic_rdData(atomic_rdData),
      .flush_ack(flush_ack),
      .flush_done(flush_done),
      .flush_v(flush_v),
      .flush_gmem_addr(flush_gmem_addr),
      .flush_data(flush_data),
      .finish(finish_exec_i),
      .atomic_can_finish(atomic_can_finish),
      .WGsDispatched(WGsDispatched),
      .nrst(nrst)
      );
   // }

   // receivers {
   always_ff @(posedge clk) begin
      rcv_gmem_addr <= rcv_gmem_addr_n;
      rcv_gmem_data <= rcv_gmem_data_n;
      rcv_be <= rcv_be_n;
      rcv_rnw <= rcv_rnw_n;

      cu_rnw_d0 <= cu_rnw;
      cu_we_d0 <= cu_we;
      cu_rqst_addr_d0 <= cu_rqst_addr;
      cu_wrData_d0 <= cu_wrData;

      if (ATOMIC_IMPLEMENT != 0) begin
         rcv_atomic_sgntr <= rcv_atomic_sgntr_n;
         rcv_atomic <= rcv_atomic_n;
         cu_atomic_d0 <= cu_atomic;
         cu_atomic_sgntr_d0 <= cu_atomic_sgntr;
         if (flush_ack) begin
            cu_atomic_d0 <= '0;
            cu_rqst_addr_d0 <= flush_gmem_addr;
            cu_wrData_d0 <= flush_data;
            cu_we_d0 <= '1;
            cu_rnw_d0 <= '0;
         end
         cu_atomic_ack_p0 <= |rcv_atomic_performed;
         atomic_rdData_v <= cu_atomic_ack_p0;

         for (int i = 0; i < N_RECEIVERS; i++) begin
            if (rcv_atomic_performed[i]) begin
               atomic_sgntr_p0 <= rcv_atomic_sgntr[i];
            end
         end
         atomic_sgntr <= atomic_sgntr_p0;
      end

      if (rcv_idle == '1) begin
         rcv_all_idle <= 'b1;
      end else begin
         rcv_all_idle <= 'b0;
      end
      rcv_priority <= rcv_priority_n;
      rcv_go <= rcv_go_n;

      for (int i = 0; i < N_RECEIVERS; i++) begin
         if (rdData_tag[C_RCV_BANK_INDX[i]] == rcv_gmem_addr[i][GMEM_WORD_ADDR_W-1:L+M+N] && rdData_tag_v[C_RCV_BANK_INDX[i]]) begin
            rcv_tag_compared[i] <= 'b1;
         end else begin
            rcv_tag_compared[i] <= 'b0;
         end
      end
      rdData_page_v_d0 <= rdData_page_v;
      rcv_wait_1st_cycle <= rcv_wait_1st_cycle_n;
      rcv_request_write_data <= rcv_request_write_data_n;

      if (!nrst) begin
         st_rcv <= '{default:get_addr};
         rcv_idle <= '0;
         rcv_read_tag <= '0;
         if (ATOMIC_IMPLEMENT != 0) begin
            rcv_atomic_rqst <= '0;
         end
         rcv_alloc_tag <= '0;
         rcv_perform_read <= '0;
         rcv_request_write_addr <= '0;
      end else begin
         st_rcv <= st_rcv_n;
         rcv_idle <= rcv_idle_n;
         rcv_read_tag <= rcv_read_tag_n;
         if (ATOMIC_IMPLEMENT != 0) begin
            rcv_atomic_rqst <= rcv_atomic_rqst_n;
         end
         rcv_alloc_tag <= rcv_alloc_tag_n;
         rcv_perform_read <= rcv_perform_read_n;
         rcv_request_write_addr <= rcv_request_write_addr_n;
      end
   end
   // }

   generate begin for (genvar i = 0; i < N_RECEIVERS; i++) begin
      always_comb begin
         st_rcv_n[i] <= st_rcv[i];
         rcv_gmem_addr_n[i] <= rcv_gmem_addr[i];
         rcv_gmem_data_n[i] <= rcv_gmem_data[i];
         rcv_read_tag_n[i] <= rcv_read_tag[i];
         if (ATOMIC_IMPLEMENT != 0) begin
            rcv_atomic_rqst_n[i] <= rcv_atomic_rqst[i];
         end
         rcv_rnw_n[i] <= rcv_rnw[i];
         rcv_atomic_n[i] <= rcv_atomic[i];
         rcv_perform_read_n[i] <= rcv_perform_read[i];
         rcv_request_write_addr_n[i] <= rcv_request_write_addr[i];
         rcv_request_write_data_n[i] <= rcv_request_write_data[i];
         rcv_wait_1st_cycle_n[i] <= rcv_wait_1st_cycle[i];
         rcv_alloc_tag_n[i] <= rcv_alloc_tag[i];
         rcv_be_n[i] <= rcv_be[i];
         rcv_atomic_sgntr_n[i] <= rcv_atomic_sgntr[i];
         rcv_idle_n[i] <= rcv_idle[i];
         rcv_priority_n[i] <= rcv_priority[i];
         rcv_rd_done_n[i] <= '0;

         case (st_rcv[i])
           get_addr : begin
              rcv_idle_n[i] <= 'b1;
              rcv_wait_1st_cycle_n[i] <= 'b0;
              rcv_request_write_data_n[i] <= 'b0;
              rcv_priority_n[i] <= '0;
              rcv_rnw_n[i] <= cu_rnw_d0;
              if (rcv_go[i]) begin
                 rcv_gmem_addr_n[i] <= $unsigned(cu_rqst_addr_d0);
                 rcv_be_n[i] <= cu_we_d0;
                 rcv_atomic_sgntr_n[i] <= cu_atomic_sgntr_d0;
                 rcv_gmem_data_n[i] <= cu_wrData_d0;
                 rcv_atomic_n[i] <= cu_atomic_d0;
                 if (!cu_atomic_d0) begin
                    st_rcv_n[i] <= get_read_tag_ticket;
                    rcv_read_tag_n[i] <= 'b1;
                 end else begin
                    st_rcv_n[i] <= requesting_atomic;
                    if (ATOMIC_IMPLEMENT != 0) begin
                       rcv_atomic_rqst_n[i] <= 'b1;
                    end
                 end
                 rcv_idle_n[i] <= 'b0;
              end
           end
           requesting_atomic : begin
              if (ATOMIC_IMPLEMENT != 0) begin
                 rcv_priority_n[i] <= rcv_priority[i] + 1;
                 if (rcv_priority[i] == '1) begin
                    rcv_atomic_rqst_n[i] <= 'b1;
                 end
                 if (rcv_atomic_ack[i]) begin
                    rcv_atomic_rqst_n[i] <= 'b0;
                 end
                 if (rcv_must_read[i]) begin
                    // rcv_must_read & rcv_atomic_performed cann't be at 1 simultaneously
                    rcv_atomic_rqst_n[i] <= 'b0;
                    rcv_rnw_n[i] <= 'b1;
                    st_rcv_n[i] <= get_read_tag_ticket;
                    rcv_read_tag_n[i] <= 'b1;
                 end
                 if (rcv_atomic_performed[i]) begin
                    rcv_atomic_rqst_n[i] <= 'b0;
                    st_rcv_n[i] <= get_addr;
                 end
              end
           end // case: requesting_atomic
           // rdAddr of tag mem is being selected
           get_read_tag_ticket : begin
              if (rcv_read_tag_ack[i]) begin
                 st_rcv_n[i] <= wait_read_tag;
                 rcv_read_tag_n[i] <= 'b0;
              end
           end
           // address is fixed and tag mem is being read
           wait_read_tag : begin
              rcv_wait_1st_cycle_n[i] <= 'b1;
              if (rcv_tag_written[i]) begin
                 if (rcv_rnw[i]) begin
                    st_rcv_n[i] <= clean;
                    rcv_alloc_tag_n[i] <= 'b1;
                 end else begin
                    if (rcv_rnw[i]) begin
                       st_rcv_n[i] <= read_cache;
                       rcv_perform_read_n[i] <= 'b1;
                    end else begin
                       st_rcv_n[i] <= request_write_addr;
                       rcv_request_write_addr_n[i] <= 'b1;
                       rcv_request_write_data_n[i] <= 'b1;
                    end
                 end
              end else if (rcv_tag_updated[i]) begin
                 st_rcv_n[i] <= alloc_tag;
                 rcv_alloc_tag_n[i] <= 'b1;
              end else begin
                 if (rcv_wait_1st_cycle[i]) begin
                    if (rcv_rnw[i]) begin
                       st_rcv_n[i] <= check_tag_rd;
                    end else begin
                       st_rcv_n[i] <= check_tag_wr;
                    end
                 end
              end // else: !if(rcv_tag_updated[i])
           end // case: wait_read_tag
           check_tag_rd : begin // rdData of tag mem are ready
              if (rcv_tag_updated[i] || (!rcv_tag_written[i] && !rcv_tag_compared[i])) begin
                 st_rcv_n[i] <= alloc_tag;
                 rcv_alloc_tag_n[i] <= 'b1;
              end else if (rcv_tag_compared[i] && rdData_page_v_d0[C_RCV_BANK_INDX[i]]) begin
                 st_rcv_n[i] <= read_cache;
                 rcv_perform_read_n[i] <= 'b1;
              end else if (!rcv_page_validated[i]) begin
                 st_rcv_n[i] <= clean;
                 rcv_alloc_tag_n[i] <= 'b1;
              end else begin
                 st_rcv_n[i] <= read_cache;
                 rcv_perform_read_n[i] <= 'b1;
              end
           end // case: check_tag_rd
           check_tag_wr : begin
              if (rcv_tag_updated[i] || (!rcv_tag_written[i] && !rcv_tag_compared[i])) begin
                 st_rcv_n[i] <= alloc_tag;
                 rcv_alloc_tag_n[i] <= 'b1;
              end else if (rcv_tag_written[i] || rcv_tag_compared[i] == 'b1) begin
                 st_rcv_n[i] <= request_write_addr;
                 rcv_request_write_addr_n[i] <= 'b1;
                 rcv_request_write_data_n[i] <= 'b1;
              end else begin
                 st_rcv_n[i] <= clean;
                 rcv_alloc_tag_n[i] <= 'b1;
              end
           end // case: check_tag_wr
           alloc_tag : begin
              if (rcv_tag_written[i]) begin
                 if (rcv_rnw[i]) begin
                    st_rcv_n[i] <= clean;
                 end else begin
                    st_rcv_n[i] <= request_write_addr;
                    rcv_request_write_addr_n[i] <= 'b1;
                    rcv_request_write_data_n[i] <= 'b1;
                    rcv_alloc_tag_n[i] <= 'b0;
                 end
              end
           end // case: alloc_tag
           clean : begin
              if (rcv_tag_updated[i]) begin
                 st_rcv_n[i] <= alloc_tag;
              end else if (rcv_page_validated[i]) begin
                 rcv_alloc_tag_n[i] <= '0;
                 if (rcv_rnw[i]) begin
                    st_rcv_n[i] <= read_cache;
                    rcv_perform_read_n[i] <= 'b1;
                 end else begin
                    st_rcv_n[i] <= request_write_addr;
                    rcv_request_write_addr_n[i] <= 'b1;
                    rcv_request_write_data_n[i] <= 'b1;
                 end
              end
           end // case: clean
           read_cache : begin
              if (rcv_tag_updated[i]) begin
                 st_rcv_n[i] <= alloc_tag;
                 rcv_alloc_tag_n[i] <= 'b1;
                 rcv_perform_read_n[i] <= 'b0;
              end else if (cache_addra == rcv_gmem_addr[i][L+M+N-1:N] && cache_read_v) begin
                 rcv_perform_read_n[i] <= '0;
                 if (ATOMIC_IMPLEMENT != 0 && rcv_atomic[i]) begin
                    rcv_atomic_rqst_n[i] <= 'b1;
                    st_rcv_n[i] <= requesting_atomic;
                 end else begin
                    st_rcv_n[i] <= get_addr;
                    rcv_gmem_addr_n[i] <= 'b0;
                    rcv_idle_n[i] <= 'b1;
                    rcv_rd_done_n[i] <= 'b1;
                 end
              end
              if (rcv_priority[i] != '1) begin
                 rcv_priority_n[i] <= rcv_priority[i] + 1;
              end
           end // case: read_cache
           request_write_addr : begin
              if (rcv_tag_updated[i]) begin
                 st_rcv_n[i] <= alloc_tag;
                 rcv_alloc_tag_n[i] <= 'b1;
                 rcv_request_write_addr_n[i] <= 'b0;
                 rcv_request_write_data_n[i] <= 'b0;
              end else if (rcv_will_write[i]) begin
                 rcv_request_write_addr_n[i] <= 'b0;
                 rcv_request_write_data_n[i] <= 'b0;
                 st_rcv_n[i] <= write_cache;
              end else if (rcv_write_in_pipeline[i]) begin
                 rcv_request_write_addr_n[i] <= '0;
                 st_rcv_n[i] <= request_write_data;
              end
              if (rcv_priority[i] != '1) begin
                 rcv_priority_n[i] <= rcv_priority[i] + 1;
              end
           end // case: request_write_addr
           request_write_data : begin
              if (rcv_will_write[i]) begin
                 st_rcv_n[i] <= write_cache;
                 rcv_request_write_data_n[i] <= '0;
              end
           end
           write_cache : begin
              if (cache_we && !rcv_will_write_d0[i]) begin
                 st_rcv_n[i] <= get_addr;
                 rcv_gmem_addr_n[i] <= 'b0;
                 rcv_idle_n[i] <= 'b1;
              end
           end
         endcase
      end // always_comb
   end end
   endgenerate
   // interface to CUs {
   always_ff @(posedge clk) begin
      cu_ready_i <= cu_ready_n;
      cuIndx_msb <= ~cuIndx_msb;
      if (ATOMIC_IMPLEMENT != 0) begin
         flush_ack <= flush_ack_n;
         flush_rcv_index <= flush_rcv_index_n;
         flush_done <= rcv_idle[flush_rcv_index];
      end
   end

   always_comb begin
      automatic logic unsigned [N_RECEIVERS_W-1:0] rcvIndx = '0;
      rcv_go_n <= '0;
      // setting ready signal for CU0
      cu_ready_n <= '0;
      flush_ack_n <= '0;
      if (ATOMIC_IMPLEMENT != 0) begin
         flush_rcv_index_n <= flush_rcv_index;
      end
      for (int j = N_RECEIVERS_CU/2-1; j >= 0; j--) begin
         rcvIndx[N_RECEIVERS_CU_W-1] = ~cuIndx_msb;
         rcvIndx[N_RECEIVERS_CU_W-2:0] = (N_RECEIVERS_CU_W-1)'($unsigned(j));
         if (rcv_idle_n[$unsigned(rcvIndx)]) begin
            if (ATOMIC_IMPLEMENT && flush_v && !flush_ack) begin
               flush_ack_n <= 'b1;
               cu_ready_n <= 'b0;
            end else begin
               flush_ack_n <= 'b0;
               cu_ready_n <= 'b1;
            end
         end
      end

      // starting receviers for CU0
      if ((cu_valid && cu_ready_i) || (ATOMIC_IMPLEMENT && flush_v && flush_ack)) begin
         for (int j = N_RECEIVERS_CU/2-1; j >= 0; j--) begin
            rcvIndx[N_RECEIVERS_CU_W-1] = cuIndx_msb;
            rcvIndx[N_RECEIVERS_CU_W-2:0] = (N_RECEIVERS_CU_W-1)'($unsigned(j));
            if (rcv_idle_n[$unsigned(rcvIndx)]) begin
               rcv_go_n[$unsigned(rcvIndx)] <= 'b1;
               flush_rcv_index_n <= $unsigned(rcvIndx);
               break;
            end
         end
      end
   end

endmodule
