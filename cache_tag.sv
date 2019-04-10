`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module cache_tag
  (
   // axi signals
   input logic                                         wr_fifo_free, // free ports have to respond to go ports immediately (in one clock cycle)
   output logic                                        wr_fifo_go = 'b0,
   input logic                                         wr_fifo_cache_ack,
   output logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] axi_rdAddr = 'b0,
   output logic                                        axi_writer_go = 'b0,
   output logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] axi_wrAddr,
   input logic                                         axi_writer_free,
   input logic                                         axi_rd_fifo_filled,
   input logic                                         axi_wvalid,
   input logic                                         axi_writer_ack,

   // receivers signals
   input logic [N_RECEIVERS-1:0]                       rcv_alloc_tag, // rcv_alloc_tag need to be set whether it is a tag to be allocated or a page to be validate
   input logic [N_RECEIVERS-1:0][GMEM_WORD_ADDR_W-1:0] rcv_gmem_addr,
   input logic [N_RECEIVERS-1:0]                       rcv_rnw,
   output logic [N_RECEIVERS-1:0]                      rcv_tag_written = '0,
   output logic [N_RECEIVERS-1:0]                      rcv_tag_updated = '0,
   output logic [N_RECEIVERS-1:0]                      rcv_page_validated = '0,
   input logic [N_RECEIVERS-1:0]                       rcv_read_tag,
   output logic [N_RECEIVERS-1:0]                      rcv_read_tag_ack,
   output logic [N_RD_PORTS-1:0]                       rdData_page_v = 'b0,
   output logic [N_RD_PORTS-1:0]                       rdData_tag_v = 'b0,
   output logic [N_RD_PORTS-1:0][TAG_W-1:0]            rdData_tag,

   // cache port a signals
   input logic                                         cache_we,
   input logic unsigned [M+L-1:0]                      cache_addra,
   input logic [(2**N)*DATA_W/8-1:0]                   cache_wea,

   // finish
   input logic                                         WGsDispatched,
   input logic                                         CUs_gmem_idle,
   input logic                                         rcv_all_idle,
   input logic [N_RECEIVERS-1:0]                       rcv_idle,
   output logic                                        finish_exec = 'b0,
   input logic                                         start_kernel,
   input logic                                         clean_cache,
   input logic                                         atomic_can_finish,

   // write pipeline
   input logic [4:0]                                   write_pipe_active,
   input logic [4:0][M-1:0]                            write_pipe_wrTag,

   input logic                                         clk,
   input logic                                         nrst
   );

   logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0]        axi_wrAddr_i = '0;
   logic [N_RD_PORTS-1:0][TAG_W-1:0]                   rdData_tag_i = '0; // on a critical path
   // axi signals {
   logic                                               wr_fifo_go_n = '0;
   logic                                               axi_writer_go_n = '0;
   // }

   // mem signals {
   logic [0:2**M-1][TAG_W-1:0]                         tag = '0;
   logic unsigned [M-1:0]                              wrAddr_tag = '0;
   logic unsigned [M-1:0]                              wrAddr_tag_n = '0;
   logic unsigned [TAG_W-1:0]                          wrData_tag = '0;
   logic unsigned [TAG_W-1:0]                          wrData_tag_n = '0;
   logic [N_RD_PORTS-1:0][M-1:0]                       rdAddr_tag = '0;
   logic [N_RD_PORTS-1:0][M-1:0]                       rdAddr_tag_n = '0;
   logic                                               we_tag = '0;
   logic                                               we_tag_n = '0;
   logic [0:2**M-1]                                    tag_v = '0;
   logic                                               we_tag_v = '0;
   logic                                               we_tag_v_n = '0;
   logic unsigned [M-1:0]                              wrAddr_tag_v = '0;
   logic unsigned [M-1:0]                              wrAddr_tag_v_n = '0;
   logic                                               wrData_tag_v = '0;
   logic                                               wrData_tag_v_n = '0;
   logic                                               clear_tag = '0;
   logic                                               clear_tag_n = '0;
   logic [0:2**M-1]                                    page_v = '0;
   logic                                               we_page_v = '0;
   logic                                               we_page_v_n = '0;
   logic unsigned [M-1:0]                              wrAddr_page_v = '0;
   logic unsigned [M-1:0]                              wrAddr_page_v_n = '0;
   logic                                               wrData_page_v = '0;
   logic                                               wrData_page_v_n = '0;
   // }
   // receivers signals {
   logic [N_RECEIVERS-1:0]                             rcv_tag_written_n = '0;
   logic [N_RECEIVERS-1:0]                             rcv_tag_updated_n = '0;
   logic [N_RECEIVERS-1:0]                             rcv_page_validated_n = '0;
   // }
   // Tag managers signals {
   typedef enum                                        {tm_idle, define_rcv_indx, check_tag_being_processed, invalidate_tag_v, invalidate_page_v, clear_tag_st, clear_dirty, check_dirty, validate_new_tag, issue_write, read_tag, wait_write_finish, issue_read, wait_read_finish, validate_new_page, wait_page_v, wait_a_little, wait_bid} st_tmanager_type;
   st_tmanager_type st_tmanager = tm_idle;
   st_tmanager_type st_tmanager_n = tm_idle;
   logic                           tmanager_free = '0;
   logic                           tmanager_free_n = '0;
   logic [N_RECEIVERS-1:0] rcv_alloc_tag_ltchd = '0;
   logic [N_RECEIVERS-1:0] rcv_alloc_tag_ltchd_n = '0;
   logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] tmanager_gmem_addr = '0;
   logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0] tmanager_gmem_addr_n = '0;

   logic [N_RECEIVERS_W-1:0]                    rcv_indx_tmanager = '0;
   logic [N_RECEIVERS_W-1:0]                    rcv_indx_tmanager_n = '0;
   logic                                        tmanager_rcv_served = '0;
   logic                                        tmanager_rcv_served_n = '0;
   logic                                        invalidate_tag = '0;
   logic                                        invalidate_tag_n = '0;

   logic                                        invalidate_tag_ack = '0;
   logic                                        invalidate_page = '0;
   logic                                        invalidate_page_n = '0;

   logic                                        validate_page = '0;
   logic                                        validate_page_n = '0;

   logic                                        page_v_tmanager_ack = '0;
   logic                                        clear_tag_tmanager = '0;
   logic                                        clear_tag_tmanager_n;

   logic                                        alloc_tag = '0;
   logic                                        alloc_tag_n = '0;
   logic                                        alloc_tag_ack = '0;
   logic                                        tmanager_issue_write = '0;
   logic                                        tmanager_issue_write_n = '0;
   logic                                        wr_issued_tmanager = '0;
   logic                                        wr_issued_tmanager_n = '0;
   logic                                        tmanager_busy = '0;
   logic                                        tmanager_busy_n = '0;

   parameter TAG_PROTECT_LEN = 7;
   // # of clock cycles before a processed tag from a tag manager can be processed by another one
   logic [TAG_PROTECT_LEN-1:0]                  tmanager_tag_protect_vec = '0;
   // helps a tag manager to clear the protection of tag
   logic                                        tmanager_tag_protect_vec_n = '0;
   logic                                        tmanager_tag_protect_v = '0;
   logic                                        tmanager_tag_protect_v_n = '0;
   logic [M-1:0]                          tmanager_tag_protect = '0;
   // after a tag has been processed by a tag manager, it will be stored with this signal.
   // It is not allowed to process the tag again before TAG_PROTECT_LEN clock cycles
   // It helps to avoid frequent allocation/deallocation of the same tag (not necessary but improve the performance)
   // It helps to insure data consistency by using the B axi channel response to clear it (necessary if the kernel reads/writes the same address region)
   logic [M-1:0]                          tmanager_tag_protect_n = '0;
   logic                                  tmanager_gmem_addr_protected = '0;
   parameter RCV_SERVED_WAIT_LEN = 2**(WRITE_PHASE_W+1);
   logic [RCV_SERVED_WAIT_LEN-1:0]        tmanager_rcv_served_wait_vec = '0;
   // helps a tag manager to wait for some time before issuing a receiver that its write requested has been executed
   logic                                  tmanager_rcv_served_wait_vec_n = '0;
   logic                                  tmanager_get_busy = '0;
   logic                                  tmanager_get_busy_ack = '0;

   parameter WAIT_LEN = 4;
   logic [WAIT_LEN:0]                     wait_vec = '0;
   logic                                  wait_vec_n = '0;
   logic [WAIT_LEN:0]                     wait_vec_invalidate_tag = '0;
   logic                                  wait_vec_invalidate_tag_n = '0;
   logic                                  wait_done = '0;
   logic                                  wait_done_n = '0;
   logic                                  tmanager_read_tag = '0;

   logic                                  tmanager_read_tag_n = '0;
   logic                                  tmanager_read_tag_ack_n = '0;
   logic                                  tmanager_read_tag_ack = '0;
   logic                                  tmanager_read_tag_ack_d0 = '0;
   logic [TAG_W-1:0]                      tmanager_tag_to_write = '0;
   logic                                  tmanager_clear_dirty = '0;

   logic                                  tmanager_clear_dirty_n = '0;
   logic                                  tmanager_clear_dirty_ack_n = '0;
   logic                                  tmanager_clear_dirty_ack = '0;
   logic                                  tmanager_wait_for_fifo_empty = '0;
   logic                                  tmanager_wait_for_fifo_empty_n = '0;
   // }

   // dirty signals {
   logic [2**M-1:0]                       dirty = '0;
   logic                                  we_dirty = '0;
   logic                                  we_dirty_n = '0;
   logic                                  wrData_dirty = '0;
   logic                                  wrData_dirty_n = '0;
   logic unsigned [M-1:0]                 wrAddr_dirty = '0;
   logic unsigned [M-1:0]                 wrAddr_dirty_n = '0;
   logic unsigned [M-1:0]                 rdAddr_dirty = '0;
   logic unsigned [M-1:0]                 rdAddr_dirty_n = '0;
   logic                                  rdData_dirty = '0;
   // }

   // axi signals {
   typedef enum                                               logic [1:0] {find_free_fifo, issue_order} axi_interface;

   logic                                                      st_axi_wr = find_free_fifo;
   logic                                                      st_axi_wr_n = find_free_fifo;
   logic [GMEM_WORD_ADDR_W-CACHE_N_BANKS_W-1:0]               axi_wrAddr_n = '0;
   // }
   // final cache clean signels {
   logic [2:0]                                                rcv_all_idle_vec = '0;
   // It is necessary to make sure that rcv_all_idle is stable for 3 clock cycles before cache cleaning at the end
   logic                                                      finish_active = '0;
   logic                                                      finish_active_n = '0;
   logic unsigned [M-1:0]                                     finish_tag_addr = '0;
   logic unsigned [M-1:0]                                     finish_tag_addr_n = '0;
   logic unsigned [M-1:0]                                     finish_tag_addr_d0 = '0;
   logic unsigned [M-1:0]                                     finish_tag_addr_d1 = '0;
   logic                                                      finish_we = '0;
   logic                                                      finish_we_n = '0;
   logic unsigned [TAG_W-1:0]                                 rdData_tag_d0 = '0;
   logic                                                      finish_issue_write = '0;
   logic                                                      finish_issue_write_n = '0;
   logic                                                      finish_exec_masked = '0;
   logic                                                      finish_exec_masked_n = '0;
   logic [2**FINISH_FIFO_ADDR_W-1:0][TAG_W+M-1:0]             finish_fifo = '0;
   logic unsigned [FINISH_FIFO_ADDR_W-1:0]                    finish_fifo_rdAddr = '0;
   logic unsigned [FINISH_FIFO_ADDR_W-1:0]                    finish_fifo_wrAddr = '0;
   logic unsigned [TAG_W+M-1:0]                               finish_fifo_dout = '0;
   logic                                                      finish_fifo_pop = '0;
   logic                                                      finish_fifo_push_n = '0;
   logic [1:0]                                                finish_fifo_push = '0;
   typedef enum                                               logic [2:0] {idle1, idle2, pre_active, active, finish} st_fill_finish_fifo_type;
   st_fill_finish_fifo_type st_fill_finish_fifo = idle1;
   st_fill_finish_fifo_type st_fill_finish_fifo_n = idle1;
   logic [FINISH_FIFO_ADDR_W-1:0]                             finish_fifo_n_rqsts = '0;
   logic [FINISH_FIFO_ADDR_W-1:0]                             finish_fifo_n_rqsts_n = '0;
   // }
   // write pipeline signals {
   logic                                                      write_pipe_contains_gmem_addr = '0;
   logic [4:0]                                                write_pipe_contains_gmem_addr_vec = '0;
   logic                                                      tmanager_waited_for_write_pipe = '0;
   logic                                                      tmanager_waited_for_write_pipe_n = '0;

   typedef enum                                               logic [1:0] {writer_idle, issue, wait_fifo_dout} st_finish_writer_type;
   st_finish_writer_type st_finish_writer = writer_idle;
   st_finish_writer_type st_finish_writer_n = writer_idle;
   // }
   // bvalid processing {
   logic                                                      write_response_rcvd = '0;
   logic                                                      wait_for_write_response = '0;
   logic                                                      wait_for_write_response_n = '0;
   // }
   assign axi_wrAddr = axi_wrAddr_i;
   initial begin
      assert(N_RD_FIFOS_TAG_MANAGER_W == 0)
        else $error("There must be a single rd fifo (from cache) for each tag manager. Otherwise b channel communcation fails!");
   end
   assign rdData_tag = rdData_tag_i;

   // finish finite state machine {
   always_comb rcv_all_idle_vec[$high(rcv_all_idle_vec)] <= rcv_all_idle;
   always_ff @(posedge clk) begin
      // pipes {
      rcv_all_idle_vec[$high(rcv_all_idle_vec)-1:0] <= rcv_all_idle_vec[$high(rcv_all_idle_vec):1];
      finish_tag_addr <= finish_tag_addr_n;
      finish_tag_addr_d0 <= finish_tag_addr;
      finish_tag_addr_d1 <= finish_tag_addr_d0;
      // }
      // set final finish signals ?
      finish_exec_masked <= finish_exec_masked_n;
      finish_exec <= '0;
      if (finish_exec_masked) begin
         if (clean_cache) begin
            if (axi_writer_free == '1 && axi_wvalid == '0) begin
               finish_exec <= 'b1;
            end
         end else begin
            finish_exec <= 'b1;
         end
      end
      if (start_kernel) begin
         finish_exec <= 'b0;
      end
      // }
      finish_we <= finish_we_n;
      finish_fifo_dout <= finish_fifo[$unsigned(finish_fifo_rdAddr)];
      if (finish_fifo_push[0] && rdData_dirty) begin
         finish_fifo[$unsigned(finish_fifo_wrAddr)] <= {rdData_tag_i[N_RD_PORTS-1], finish_tag_addr_d1};
      end
      if (!nrst) begin
         finish_active <= '0;
         finish_issue_write <= '0;
         st_fill_finish_fifo <= idle1;
         finish_fifo_push <= '0;
         finish_fifo_wrAddr <= '0;
         finish_fifo_n_rqsts <= 0;
         st_finish_writer <= writer_idle;
         finish_fifo_rdAddr <= '0;
      end else begin
         finish_active <= finish_active_n;
         finish_issue_write <= finish_issue_write_n;
         st_fill_finish_fifo <= st_fill_finish_fifo_n;
         finish_fifo_push[$high(finish_fifo_push)-1:0] <= finish_fifo_push[$high(finish_fifo_push):1];
         finish_fifo_push[$high(finish_fifo_push)] <= finish_fifo_push_n;
         if (finish_fifo_push[0] && rdData_dirty) begin
            finish_fifo_wrAddr <= finish_fifo_wrAddr + 1;
         end
         st_finish_writer <= st_finish_writer_n;
         if (finish_fifo_pop) begin
            finish_fifo_rdAddr <= finish_fifo_rdAddr + 1;
         end
         if (finish_fifo_push[0] && rdData_dirty && !finish_fifo_pop) begin
            finish_fifo_n_rqsts <= finish_fifo_n_rqsts + 1;
         end else if ((!finish_fifo_push[0] || !rdData_dirty) && finish_fifo_pop) begin
            finish_fifo_n_rqsts <= finish_fifo_n_rqsts - 1;
         end
      end
   end // always_ff @ (posedge clk)
   always_comb begin
      st_finish_writer_n <= st_finish_writer;
      finish_issue_write_n <= finish_issue_write;
      case (st_finish_writer)
        writer_idle : begin
           if (finish_fifo_n_rqsts != 0) begin
              finish_issue_write_n <= 'b1;
              st_finish_writer_n <= issue;
           end
        end
        issue : begin
           finish_issue_write_n <= '0;
           st_finish_writer_n <= wait_fifo_dout;
        end
        wait_fifo_dout : begin
           st_finish_writer_n <= writer_idle;
        end
      endcase
   end
   always_comb begin
      st_fill_finish_fifo_n <= st_fill_finish_fifo;
      finish_tag_addr_n <= finish_tag_addr;
      finish_active_n <= finish_active;
      finish_fifo_push_n <= '0;
      finish_we_n <= '0;
      finish_exec_masked_n <= '0;
      case (st_fill_finish_fifo)
        idle1 : begin
           finish_tag_addr_n <= '0;
           if (WGsDispatched) begin
              st_fill_finish_fifo_n <= idle2;
           end
        end
        idle2 : begin
           if (CUs_gmem_idle &&
               rcv_all_idle_vec == '1 &&
               atomic_can_finish) begin
              if (clean_cache == '0) begin
                 st_fill_finish_fifo_n <= finish;
              end else begin
                 finish_active_n <= 'b1;
              end
           end
           if (finish_active) begin
              st_fill_finish_fifo_n <= pre_active;
           end
        end
        pre_active : begin
           finish_tag_addr_n <= finish_tag_addr + 1;
           finish_fifo_push_n <= 'b1;
           finish_we_n <= 'b1;
           st_fill_finish_fifo_n <= active;
        end
        active :  begin
           if (finish_fifo_n_rqsts < 2**FINISH_FIFO_ADDR_W-2) begin
              finish_tag_addr_n <= finish_tag_addr + 1;
              finish_fifo_push_n <= 'b1;
              finish_we_n <= 'b1;
           end
           if (finish_tag_addr == '0) begin
              st_fill_finish_fifo_n <= finish;
           end
        end
        finish : begin
           finish_exec_masked_n <= 'b1;
           if (start_kernel) begin
              st_fill_finish_fifo_n <= idle1;
              finish_active_n <= '0;
              finish_exec_masked_n <= '0;
           end
        end
      endcase
   end
   // }
   // write pipeline check {
   generate begin for (genvar i = 0; i <= 4; i++) begin
      always_ff @(posedge clk) begin
         if (tmanager_gmem_addr[M+L-1:L] == write_pipe_wrTag[i] && write_pipe_active[i]) begin
            write_pipe_contains_gmem_addr_vec <= 'b1;
         end
      end
   end end
   endgenerate
   always_comb begin
      write_pipe_contains_gmem_addr <= |write_pipe_contains_gmem_addr;
   end

   // }
   // tag managers {
   always_ff @(posedge clk) begin
      rcv_alloc_tag_ltchd <= rcv_alloc_tag_ltchd_n;
      tmanager_gmem_addr <= tmanager_gmem_addr_n;
      rcv_indx_tmanager <= rcv_indx_tmanager_n;
      if (WRITE_PHASE_W > 1) begin
         tmanager_rcv_served <= tmanager_rcv_served_n;
      end
      tmanager_get_busy_ack <= '0;
      if (tmanager_get_busy) begin
         tmanager_get_busy_ack <= 'b1;
      end
      wr_fifo_go <= wr_fifo_go_n;

      tmanager_tag_protect <= tmanager_tag_protect_n;
      tmanager_tag_protect_vec[TAG_PROTECT_LEN-2:0] <= tmanager_tag_protect_vec[TAG_PROTECT_LEN-1:1];
      tmanager_tag_protect_vec[TAG_PROTECT_LEN-1] <= tmanager_tag_protect_vec_n;
      tmanager_rcv_served_wait_vec[RCV_SERVED_WAIT_LEN-2:0] <= tmanager_rcv_served_wait_vec[RCV_SERVED_WAIT_LEN-1:1];
      tmanager_rcv_served_wait_vec[RCV_SERVED_WAIT_LEN-1] <= tmanager_rcv_served_wait_vec_n;
      tmanager_tag_protect_v <= tmanager_tag_protect_v_n;

      wait_vec[WAIT_LEN-2:0] <= wait_vec[WAIT_LEN-1:1];
      wait_vec[WAIT_LEN-1] <= wait_vec_n;
      wait_vec_invalidate_tag[WAIT_LEN-1:0] <= wait_vec_invalidate_tag[WAIT_LEN:1];
      wait_vec_invalidate_tag[WAIT_LEN] <= wait_vec_invalidate_tag_n;
      if (tmanager_read_tag_ack_d0) begin
         tmanager_tag_to_write <= rdData_tag_i[N_RD_PORTS-1];
      end

      if (nrst) begin
         st_tmanager <= st_tmanager_n;
         tmanager_free <= tmanager_free_n;
         invalidate_tag <= invalidate_tag_n;
         invalidate_page <= invalidate_page_n;
         validate_page <= validate_page_n;
         clear_tag_tmanager <= clear_tag_tmanager_n;
         tmanager_issue_write <= tmanager_issue_write_n;
         tmanager_busy <= tmanager_busy_n;
         alloc_tag <= alloc_tag_n;
         tmanager_read_tag <= tmanager_read_tag_n;
         tmanager_clear_dirty <= tmanager_clear_dirty_n;
         wait_done <= wait_done_n;
         tmanager_wait_for_fifo_empty <= tmanager_wait_for_fifo_empty_n;
         tmanager_waited_for_write_pipe <= tmanager_waited_for_write_pipe_n;
      end else begin
         st_tmanager <= tm_idle;
         tmanager_free <= '0;
         invalidate_tag <= '0;
         invalidate_page <= '0;
         validate_page <= '0;
         clear_tag_tmanager <= '0;
         tmanager_issue_write <= '0;
         tmanager_busy <= '0;
         alloc_tag <= '0;
         tmanager_read_tag <= '0;
         tmanager_clear_dirty <= '0;
         wait_done <= '0;
         tmanager_wait_for_fifo_empty <= '0;
         tmanager_waited_for_write_pipe <= '0;
      end
   end // always_ff @ (posedge clk)

   always_comb begin
      // next initialization {
      st_tmanager_n <= st_tmanager;
      tmanager_free_n <= tmanager_free;
      rcv_alloc_tag_ltchd_n <= rcv_alloc_tag_ltchd;
      tmanager_gmem_addr_n <= tmanager_gmem_addr;
      rcv_indx_tmanager_n <= rcv_indx_tmanager;
      invalidate_tag_n <= invalidate_tag;
      invalidate_page_n <= invalidate_page;
      validate_page_n <= validate_page;
      clear_tag_tmanager_n <= clear_tag_tmanager;
      tmanager_issue_write_n <= tmanager_issue_write;
      tmanager_busy_n <= tmanager_busy;
      tmanager_get_busy <= '0;
      alloc_tag_n <= alloc_tag;
      wait_vec_n <= '0;
      wait_vec_invalidate_tag_n <= '0;
      tmanager_read_tag_n <= tmanager_read_tag;
      tmanager_clear_dirty_n <= tmanager_clear_dirty;
      wait_done_n <= wait_done;
      tmanager_wait_for_fifo_empty_n <= tmanager_wait_for_fifo_empty;
      tmanager_waited_for_write_pipe_n <= tmanager_waited_for_write_pipe;
      if (tmanager_tag_protect_vec[0]) begin
         tmanager_tag_protect_v_n <= 'b0;
      end else begin
         tmanager_tag_protect_v_n <= tmanager_tag_protect_v;
      end
      if (WRITE_PHASE_W > 1) begin
         tmanager_rcv_served_n <= tmanager_rcv_served;
         if (rcv_idle[rcv_indx_tmanager] || tmanager_rcv_served_wait_vec[0]) begin
            tmanager_rcv_served_n <= 'b1;
         end
      end
      tmanager_tag_protect_n <= tmanager_tag_protect;
      tmanager_tag_protect_vec_n <= '0;
      tmanager_rcv_served_wait_vec_n <= '0;
      wr_fifo_go_n <= '0;
      // }
      case (st_tmanager)
        tm_idle : begin
           tmanager_waited_for_write_pipe_n <= '0;
           rcv_alloc_tag_ltchd_n <= rcv_alloc_tag;
           if (tmanager_rcv_served || WRITE_PHASE_W == 1) begin
              if (rcv_alloc_tag != '0) begin
                 st_tmanager_n <= define_rcv_indx;
              end
           end
        end
        define_rcv_indx : begin
           st_tmanager_n <= tm_idle; // in case rcv_alloc_tag_ltchd are all zeros
           for (int j = 0; j < N_RECEIVERS; j++) begin
              if (rcv_alloc_tag_ltchd[j] && rcv_alloc_tag[j]) begin
                 // rcv_alloc_tag must be checked because it may be deasserted while rcv_alloc_tag_latched is still asserted
                 rcv_indx_tmanager_n <= j;
                 rcv_alloc_tag_ltchd_n[j] <= '0;
                 tmanager_gmem_addr_n <= rcv_gmem_addr[j][GMEM_WORD_ADDR_W-1:N];
                 st_tmanager_n <= check_tag_being_processed;
                 break;
              end
           end
        end // case: define_rcv_indx
        check_tag_being_processed : begin
           // check if the corresponding cache addr is being processed by another tmanager {{{
           // if an address of the requested tag is already in the write pipeline; the FSM should go and try to pick up a new alloc request
           // Otherwise it may  stay in this state, as long as no anther tmanager is processing the tag and the alloc request deasserted, e.g. another tmanager allocated the tag
           // Processing a no more requested tag may lead to the following problem:
           // a rcv wants to write, a tmanager thinks wrongly that somebody wants to read the address,
           // as soon as the tag is allocated, the rcv may write and the data may be overwritten!
           tmanager_get_busy <= 'b1;
           if (tmanager_get_busy_ack) begin
              if (write_pipe_contains_gmem_addr == '0 &&
                  tmanager_gmem_addr_protected == '0) begin
                 // tmanager_gmem_addr_protected has a delay of 1 clock cycle
                 invalidate_tag_n <= 'b1; // kokodake
                 st_tmanager_n <= invalidate_tag_v;
                 tmanager_busy_n <= 'b1;
                 tmanager_tag_protect_v_n <= 'b1;
                 tmanager_tag_protect_n <= tmanager_gmem_addr[M+L-1:L];
              end else begin
                 st_tmanager_n <= define_rcv_indx;
                 tmanager_get_busy <= '0;
              end
           end // if (tmanager_get_busy_ack)

           if (tmanager_busy && tmanager_gmem_addr[M+L-1:L] == tmanager_gmem_addr[M+L-1:L]) begin
              tmanager_get_busy <= '0;
              tmanager_busy_n <= '0;
              tmanager_tag_protect_v_n <= '0;
              invalidate_tag_n <= '0;
              st_tmanager_n <= define_rcv_indx;
           end
        end // case: check_tag_being_processed
        invalidate_tag_v : begin
           if (WRITE_PHASE_W > 1) begin
              tmanager_rcv_served_n <= '0;
           end
           if (invalidate_tag_ack) begin
              invalidate_tag_n <= '0;
              clear_tag_tmanager_n <= 'b1;
              st_tmanager_n <= clear_tag_st;
              alloc_tag_n <= 'b1;
           end
        end // case: invalidate_tag_v
        clear_tag_st : begin
           if (alloc_tag_ack) begin
              clear_tag_tmanager_n <= 'b0;
              alloc_tag_n <= 'b0;
              st_tmanager_n <= invalidate_page_v;
              invalidate_page_n <= '1;
           end
        end
        invalidate_page_v : begin
           if (page_v_tmanager_ack) begin
              invalidate_page_n <= '0;
              st_tmanager_n <= check_dirty;
              wait_vec_invalidate_tag_n <= '1;
              if (write_pipe_contains_gmem_addr) begin
                 tmanager_waited_for_write_pipe_n <= 'b1;
              end
           end
        end
        check_dirty : begin
           if (write_pipe_contains_gmem_addr) begin
              tmanager_waited_for_write_pipe_n <= 'b1;
              if (wait_vec_invalidate_tag[0]) begin
                 wait_done_n <= 'b1;
              end
           end else begin
              wait_done_n <= '0;
              if (wait_vec_invalidate_tag[0] || wait_done) begin
                 if (tmanager_waited_for_write_pipe || rdData_dirty) begin
                    st_tmanager_n <= read_tag;
                    tmanager_read_tag_n <= 'b1;
                    tmanager_clear_dirty_n <= 'b1;
                 end else begin
                    // Populating the cache line with the new content should be done before validating the new tag
                    // Otherwise, some receivers may write the cache directly after tag validation and the written data will
                    // be overwritten by the one from the global memory
                    // Therefore, issue_read -> validate_tag -> validate_page
                    if (rcv_rnw[rcv_indx_tmanager]) begin
                       st_tmanager_n <= issue_read;
                       wr_fifo_go_n <= 'b1; // axi start
                    end else begin
                       st_tmanager_n <= validate_new_tag;
                       alloc_tag_n <= 'b1;
                    end
                 end
              end
           end
        end
        validate_new_tag : begin
           if (alloc_tag_ack) begin
              alloc_tag_n <= 'b0;
           end

           if (rcv_rnw[rcv_indx_tmanager]) begin
              st_tmanager_n <= validate_new_page;
              validate_page_n <= 'b1;
           end else begin
              st_tmanager_n <= wait_a_little;
              wait_vec_n <= 'b1;
           end
        end
        wait_a_little : begin
           // necessary because rcv_alloc_tag does not react immediately in case of validating a tag for a write
           if (wait_vec[0]) begin
              st_tmanager_n <= tm_idle;
              tmanager_busy_n <= '0;
              tmanager_tag_protect_vec_n <= 'b1;
              tmanager_rcv_served_wait_vec_n <= 'b1;
           end
        end
        read_tag : begin
           // $display("tag read by tmanager");
           tmanager_waited_for_write_pipe_n <= '0;
           if (tmanager_read_tag_ack_d0) begin
              st_tmanager_n <= issue_write;
              tmanager_issue_write_n <= 'b1;
           end
        end
        issue_write : begin
           // $display("write issued");
           if (wr_issued_tmanager) begin
              st_tmanager_n <= wait_write_finish;
              tmanager_issue_write_n <= '0;
           end
        end
        wait_write_finish : begin
           if (axi_rd_fifo_filled == 'b1) begin
              if ($unsigned(tmanager_tag_to_write) == $unsigned(tmanager_gmem_addr[TAG_W+M+L-1:M+L])) begin
                 // the tag to read is the same dirty one!
                 // the tmanager should wait until the write transaction is completely finished
                 // otherwise data may become inconsistent
                 st_tmanager_n <= wait_bid;
              end else if (tmanager_clear_dirty) begin
                 st_tmanager_n <= clear_dirty;
              end else begin
                 // +
                 if (rcv_rnw[rcv_indx_tmanager]) begin
                    st_tmanager_n <= issue_read;
                    wr_fifo_go_n <= 'b1;
                 end else begin
                    st_tmanager_n <= validate_new_tag;
                    alloc_tag_n <= 'b1;
                 end
              end // else: !if(tmanager_clear_dirty)
              // +
           end
        end // case: wait_write_finish
        wait_bid : begin
           if (wait_for_write_response == 'b0) begin
              if (tmanager_clear_dirty) begin
                 st_tmanager_n <= clear_dirty;
              end else begin
                 // +
                 if (rcv_rnw[rcv_indx_tmanager]) begin
                    st_tmanager_n <= issue_read;
                    wr_fifo_go_n <= 'b1;
                 end else begin
                    st_tmanager_n <= validate_new_tag;
                    alloc_tag_n <= 'b1;
                 end
                 // +
              end // else: !if(tmanager_clear_dirty)
           end
        end // case: wait_bid
        clear_dirty : begin
           if (tmanager_clear_dirty == 'b0) begin
              if (rcv_rnw[rcv_indx_tmanager]) begin
                 st_tmanager_n <= issue_read;
                 wr_fifo_go_n <= 'b1;
              end else begin
                 st_tmanager_n <= validate_new_tag;
                 alloc_tag_n <= 'b1;
              end
           end
        end // case: clear_dirty
        issue_read : begin
           st_tmanager_n <= wait_read_finish;
        end
        wait_read_finish : begin
           if (wr_fifo_free) begin
              st_tmanager_n <= validate_new_tag;
              alloc_tag_n <= 'b1;
           end
        end
        validate_new_page : begin
           if (page_v_tmanager_ack) begin
              validate_page_n <= '0;
              st_tmanager_n <= wait_page_v;
           end
        end
        wait_page_v : begin
           st_tmanager_n <= tm_idle;
           tmanager_busy_n <= '0;
           tmanager_tag_protect_vec_n <= 'b1;
           tmanager_rcv_served_wait_vec_n <= 'b1;
        end
      endcase // case (st_tmanager)
      if (tmanager_read_tag_ack_n) begin
         tmanager_read_tag_n <= 'b0;
      end
      if (tmanager_clear_dirty_ack) begin
         tmanager_clear_dirty_n <= 'b0;
      end
   end
   // }
   // tag mem {
   always_ff @(posedge clk) begin
      clear_tag <= clear_tag_n;
      we_tag <= we_tag_n;
      tmanager_read_tag_ack <= tmanager_read_tag_ack_n;
      tmanager_read_tag_ack_d0 <= tmanager_read_tag_ack;
      wrData_tag <= wrData_tag_n;
      wrAddr_tag <= wrAddr_tag_n;
      rdAddr_tag <= rdAddr_tag_n;
      rdData_tag_d0 <= rdData_tag_i[N_RD_PORTS-1];
   end
   always_ff @(posedge clk) begin
      if (we_tag) begin
         tag[$unsigned(wrAddr_tag)] <= wrData_tag;
      end
      for (int i = 0; i < N_RD_PORTS; i++) begin
         rdData_tag_i[i] <= tag[$unsigned(rdAddr_tag[i])];
      end
   end
   always_comb begin
      // write tag
      alloc_tag_ack <= '0;
      we_tag_n <= '0;
      wrData_tag_n <= tmanager_gmem_addr[GMEM_WORD_ADDR_W-N-1:M+L];
      wrAddr_tag_n <= tmanager_gmem_addr[M+L-1:L];
      clear_tag_n <= '0;
      if (alloc_tag) begin
         alloc_tag_ack <= 'b1;
         we_tag_n <= ~clear_tag_tmanager;
         clear_tag_n <= clear_tag_tmanager;
         wrData_tag_n <= tmanager_gmem_addr[GMEM_WORD_ADDR_W-N-1:M+L]; // (27:10) = 18 bits
         wrAddr_tag_n <= tmanager_gmem_addr[M+L-1:L];
      end

      // read tag
      rcv_read_tag_ack <= '0;
      // first ports (default 3) serve the receivers
      // excluding read ports
      for (int i = 0; i <= N_RD_PORTS-2; i++) begin
         rdAddr_tag_n[i] <= rcv_gmem_addr[0][L+M+N-1:L+N];
         for (int j = 0; j < N_RECEIVERS/N_RD_PORTS; j++) begin
            if (rcv_read_tag[i + j*N_RD_PORTS]) begin
               rdAddr_tag_n[i] <= rcv_gmem_addr[i+j*N_RD_PORTS][L+M+N-1:L+N];
               rcv_read_tag_ack[i + j*N_RD_PORTS] <= 'b1;
               break;
            end
         end
      end
      // the last read port serves the tmanagers in addition to the receivers
      rdAddr_tag_n[N_RD_PORTS-1] <= rcv_gmem_addr[0][L+M+N-1:L+N];
      tmanager_read_tag_ack_n <= '0;
      if (finish_active) begin
         rdAddr_tag_n[N_RD_PORTS-1] <= finish_tag_addr;
      end else if (tmanager_read_tag != '0) begin
         if (tmanager_read_tag) begin
            rdAddr_tag_n[N_RD_PORTS-1] <= tmanager_gmem_addr[M+L-1:L];
            tmanager_read_tag_ack_n <= 'b1;
         end
      end else begin
         // read tag
         for (int j = 0; j < N_RECEIVERS/N_RD_PORTS; j++) begin
            if (rcv_read_tag[N_RD_PORTS-1+j*N_RD_PORTS]) begin
               rdAddr_tag_n[N_RD_PORTS-1] <= rcv_gmem_addr[N_RD_PORTS-1+j*N_RD_PORTS][L+M+N-1:L+N];
               rcv_read_tag_ack[N_RD_PORTS-1+j*N_RD_PORTS] <= 'b1;
               break;
            end
         end
      end
   end
   // }
   // tag_valid {
   always_ff @(posedge clk) begin
      we_tag_v <= we_tag_v_n;
      wrAddr_tag_v <= wrAddr_tag_v_n;
      wrData_tag_v <= wrData_tag_v_n;
   end
   generate begin for (genvar i = 0; i < N_RD_PORTS; i++) begin
      always_ff @(posedge clk) begin
         rdData_tag_v[i] <= tag_v[$unsigned(rdAddr_tag[i])];
      end
   end end
   endgenerate
   always_ff @(posedge clk) begin
      if (we_tag_v) begin
         tag_v[$unsigned(wrAddr_tag_v)] <= wrData_tag_v;
      end
   end
   always_comb begin
      invalidate_tag_ack <= '0;
      we_tag_v_n <= '0;
      wrData_tag_v_n <= '0;
      wrAddr_tag_v_n <= tmanager_gmem_addr[M+L-1:L];
      if (finish_active == 'b0) begin
         if ((alloc_tag & ~clear_tag_tmanager) == '0) begin
            if (invalidate_tag) begin
               invalidate_tag_ack <= 'b1;
               we_tag_v_n <= 'b1;
               wrData_tag_v_n <= 'b0;
               wrAddr_tag_v_n <= tmanager_gmem_addr[M+L-1:L];
            end
         end else begin
            if (alloc_tag) begin
               if (!clear_tag_tmanager) begin
                  we_tag_v_n <= 'b1;
                  wrData_tag_v_n <= 'b1;
                  wrAddr_tag_v_n <= tmanager_gmem_addr[M+L-1:L];
               end
            end
         end
      end else begin // if (finish_active)
         we_tag_v_n <= finish_we;
         wrAddr_tag_v_n <= finish_tag_addr_d0;
         wrData_tag_v_n <= 'b0;
      end
   end
   // }
   // dirty mem {
   always_ff @(posedge clk) begin
      rdData_dirty <= dirty[$unsigned(rdAddr_dirty)];
      if (we_dirty) begin
         dirty[$unsigned(wrAddr_dirty)] <= wrData_dirty;
      end
   end

   always_ff @(posedge clk) begin
      we_dirty <= we_dirty_n;
      tmanager_clear_dirty_ack <= tmanager_clear_dirty_ack_n;
      if (!finish_active) begin
         rdAddr_dirty <= tmanager_gmem_addr[M+L-1:L];
      end else begin
         rdAddr_dirty <= finish_tag_addr;
      end
      wrData_dirty <= wrData_dirty_n;
      wrAddr_dirty <= wrAddr_dirty_n;
   end // always_ff @ (posedge clk)

   always_comb begin
      wrAddr_dirty_n <= cache_addra[M+L-1:L];
      tmanager_clear_dirty_ack_n <= '0;
      if (cache_we) begin
         wrData_dirty_n <= 'b1;
         we_dirty_n <= 'b1;
      end else if (finish_active == 'b0) begin
         wrData_dirty_n <= '0;
         we_dirty_n <= '0;
         if (tmanager_clear_dirty) begin
            tmanager_clear_dirty_ack_n <= 'b1;
            we_dirty_n <= 'b1;
            wrAddr_dirty_n <= tmanager_gmem_addr[M+L-1:L];
         end
      end else begin
         wrData_dirty_n <= 'b0;
         we_dirty_n <= finish_we; // important for manage active
         wrAddr_dirty_n <= finish_tag_addr_d0;
      end
   end
   // }
   // axi channels control {
   always_ff @(posedge clk) begin
      wr_issued_tmanager <= wr_issued_tmanager_n;
      axi_wrAddr_i <= axi_wrAddr_n;
      axi_writer_go <= axi_writer_go_n;
      axi_rdAddr[L-1:0] <= '0;
      axi_rdAddr[GMEM_WORD_ADDR_W-N-1:L] <= tmanager_gmem_addr[GMEM_WORD_ADDR_W-N-1:L];
      if (nrst) begin
         st_axi_wr <= st_axi_wr_n;
         wait_for_write_response <= wait_for_write_response_n;
      end else begin
         st_axi_wr <= find_free_fifo;
         wait_for_write_response <= '0;
      end
   end // always_ff @ (posedge clk)

   always_comb begin
      wr_issued_tmanager_n <= '0;
      st_axi_wr_n <= st_axi_wr;
      axi_wrAddr_n <= axi_wrAddr_i;
      axi_writer_go_n <= '0;
      finish_fifo_pop <= '0;
      if (axi_writer_ack) begin
         wait_for_write_response_n <= '0;
      end else begin
         wait_for_write_response_n <= wait_for_write_response;
      end
      case (st_axi_wr)
        find_free_fifo : begin
           if (tmanager_issue_write && axi_writer_free && !wait_for_write_response) begin
              wr_issued_tmanager_n <= 'b1;
              wait_for_write_response_n <= 'b1;
              axi_wrAddr_n[GMEM_WORD_ADDR_W-N-1:L] <= {tmanager_tag_to_write, tmanager_gmem_addr[M+L-1:L]};
              axi_writer_go_n <= 'b1;
              st_axi_wr_n <= issue_order;
           end
           if (finish_issue_write) begin
              if (axi_writer_free) begin
                 finish_fifo_pop <= 'b1;
                 axi_wrAddr_n[GMEM_WORD_ADDR_W-N-1:L] <= finish_fifo_dout;
                 axi_writer_go_n <= 'b1;
                 st_axi_wr_n <= issue_order;
              end
           end
        end
        issue_order : begin // just a wait state
           st_axi_wr_n <= find_free_fifo;
        end
      endcase
   end
   // }
   // page_valid {
   always_ff @(posedge clk) begin
      wrAddr_page_v <= wrAddr_page_v_n;
      wrData_page_v <= wrData_page_v_n;
      we_page_v <= we_page_v_n;
   end

   generate begin for (genvar i = 0; i < N_RD_PORTS; i++) begin
      always_ff @(posedge clk) begin
         rdData_page_v[i] <= page_v[$unsigned(rdAddr_tag[i])];
      end
   end end
   endgenerate

   always_ff @(posedge clk) begin
      if (we_page_v) begin
         page_v[$unsigned(wrAddr_page_v)] <= wrData_page_v;
      end
   end

   always_comb begin
      page_v_tmanager_ack <= '0;
      we_page_v_n <= '0;
      wrData_page_v_n <= '0;
      wrAddr_page_v_n <= tmanager_gmem_addr[M+L-1:L];
      if (invalidate_page) begin
         page_v_tmanager_ack <= 'b1;
         we_page_v_n <= 'b1;
         wrData_page_v_n <= 'b0;
         wrAddr_page_v_n <= tmanager_gmem_addr[M+L-1:L];
      end
      if (validate_page) begin
         page_v_tmanager_ack <= 'b1;
         we_page_v_n <= 'b1;
         wrData_page_v_n <= 'b1;
         wrAddr_page_v_n <= tmanager_gmem_addr[M+L-1:L];
      end
      if (finish_active) begin
         we_page_v_n <= finish_we;
         wrData_page_v_n <= '0;
         wrAddr_page_v_n <= finish_tag_addr_d0;
      end
   end
   // }
   // rcv status early update {
   always_ff @(posedge clk) begin
      rcv_tag_written <= rcv_tag_written_n;
      rcv_tag_updated <= rcv_tag_updated_n;
      rcv_page_validated <= rcv_page_validated_n;
   end

   generate begin for (genvar i = 0; i < N_RECEIVERS; i++) begin
      always_comb begin
         rcv_page_validated_n[i] <= '0;
         if (we_page_v && wrData_page_v) begin
            if (rcv_gmem_addr[i][M+L+N-1:L+N] == wrAddr_page_v) begin
               rcv_page_validated_n[i] <= 'b1;
            end
         end
      end
   end end
   endgenerate

   generate begin for (genvar i = 0; i < N_RECEIVERS; i++) begin
      always_comb begin
         rcv_tag_written_n[i] <= 'b0;
         rcv_tag_updated_n[i] <= 'b0;
         if (rcv_gmem_addr[i][M+L+N-1:N+L] == wrAddr_tag) begin
            if (we_tag && rcv_gmem_addr[i][GMEM_WORD_ADDR_W-1:M+L+N] == wrData_tag) begin
               rcv_tag_written_n[i] <= 'b1;
            end
            if (clear_tag || (we_tag && rcv_gmem_addr[i][GMEM_WORD_ADDR_W-1:M+L+N] != wrData_tag)) begin
               rcv_tag_updated_n[i] <= 'b1;
            end
         end
      end
   end end
   endgenerate
   // }
endmodule
