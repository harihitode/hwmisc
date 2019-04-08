`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module gmem_atomics
  (
   input logic [N_RECEIVERS-1:0][DATA_W/8-1:0]         rcv_atomic_type,
   input logic [N_RECEIVERS-1:0]                       rcv_atomic_rqst,
   input logic [N_RECEIVERS-1:0][GMEM_WORD_ADDR_W-1:0] rcv_gmem_addr,
   input logic [N_RECEIVERS-1:0][DATA_W-1:0]           rcv_gmem_data,
   output logic [N_RECEIVERS-1:0]                      rcv_must_read = 'b0,
   output logic [N_RECEIVERS-1:0]                      rcv_atomic_ack = 'b0,

   // read data path (in)
   input logic unsigned [GMEM_WORD_ADDR_W-N-1:0]       gmem_rdAddr_p0,
   input logic [DATA_W*CACHE_N_BANKS-1:0]              gmem_rdData,
   input logic                                         gmem_rdData_v_p0,

   // atomic data path (out)
   output logic [DATA_W-1:0]                           atomic_rdData,
   output logic [N_RECEIVERS-1:0]                      rcv_retire = 'b0, // this signals implies the validety of atomic_rdData
   // it is 2 clock cycles in advance

   // atomic flushing
   output logic                                        flush_v = '0,
   output logic unsigned [GMEM_WORD_ADDR_W-1:0]        flush_gmem_addr = '0,
   output logic [DATA_W-1:0]                           flush_data = '0,
   input logic                                         flush_ack,
   input logic                                         flush_done,

   input logic                                         finish,
   output logic                                        atomic_can_finish = 'b1,
   input logic                                         WGsDispatched,
   input logic                                         clk,
   input logic                                         nrst
   );

   // general control signals {
   (* max_fanout = 60 *) logic [N_RECEIVERS_W-1:0] rcv_slctd_indx = 0;
   (* max_fanout = 40 *) logic [N_RECEIVERS_W-1:0] rcv_slctd_indx_d0 = 0;
   logic                                               check_rqst = '0;
   logic                                               check_rqst_d0 = '0;
   (* max_fanout = 60 *) logic [2:0] rqst_type = '0;
   logic unsigned [DATA_W-1:0]                         rqst_val = '0;
   logic unsigned [GMEM_WORD_ADDR_W-1:0]               rqst_gmem_addr = '0;
   logic                                               rcv_half_select = '0;
   logic                                               rcv_is_reading = '0;
   // }
   // atomic max signals {
   typedef enum                                        logic [2:0] {atomic_idle, listening, latch_gmem_data, select_word, functioning} atomic_unit_state;
   atomic_unit_state st_amax = atomic_idle;
   atomic_unit_state st_amax_n = atomic_idle;
   logic unsigned [GMEM_WORD_ADDR_W-1:0]               amax_gmem_addr = '0;
   logic unsigned [GMEM_WORD_ADDR_W-1:0]               amax_gmem_addr_n = '0;
   logic unsigned [DATA_W-1:0]                         amax_data = '0;
   logic unsigned [DATA_W-1:0]                         amax_data_n = '0;
   logic unsigned [DATA_W-1:0]                         amax_data_d0 = '0;
   logic                                               amax_addr_v = '0;
   logic                                               amax_addr_v_n = '0;
   logic                                               amax_addr_v_d0 = '0;
   logic                                               amax_exec = '0;
   logic                                               amax_exec_d0 = '0;
   logic                                               amax_latch_gmem_rdData = '0;
   logic                                               amax_latch_gmem_rdData_n = '0;
   // }
   // atomic add signals {
   atomic_unit_state st_aadd = atomic_idle;
   atomic_unit_state st_aadd_n = atomic_idle;
   logic unsigned [GMEM_WORD_ADDR_W-1:0] aadd_gmem_addr = '0;
   logic unsigned [GMEM_WORD_ADDR_W-1:0] aadd_gmem_addr_n = '0;
   logic unsigned [DATA_W-1:0]           aadd_data = '0;
   logic unsigned [DATA_W-1:0]           aadd_data_n = '0;
   logic unsigned [DATA_W-1:0]           aadd_data_d0 = '0;
   logic [DATA_W*CACHE_N_BANKS-1:0]      gmem_rdData_ltchd = '0;
   logic                                 aadd_latch_gmem_rdData = '0;
   logic                                 aadd_latch_gmem_rdData_n = '0;
   logic                                 aadd_addr_v = '0;
   logic                                 aadd_addr_v_n = '0;
   logic                                 aadd_addr_v_d0 = '0;
   logic                                 aadd_exec = '0;
   logic                                 aadd_exec_d0 = '0;
   // }
   // flushing aadd results {
   typedef enum                          {flush_idle, dirty, flushing, wait_flush_done} flush_state_type;
   flush_state_type st_aadd_flush = flush_idle;
   flush_state_type st_aadd_flush_n = flush_idle;
   parameter FLUSH_TIMER_W = 3;
   logic unsigned [FLUSH_TIMER_W-1:0]    aadd_flush_timer = '0;
   logic unsigned [FLUSH_TIMER_W-1:0]    aadd_flush_timer_n = '0;
   logic                                 aadd_flush_rqst = '0;
   logic                                 aadd_flush_rqst_n = '0;
   logic                                 aadd_flush_started = '0;
   logic                                 aadd_flush_done = '0;
   logic                                 flush_ack_d0 = '0;
   logic                                 aadd_dirty_content = '0;
   logic                                 aadd_dirty_content_n = '0;
   logic                                 WGsDispatched_ltchd = '0;
   logic                                 aadd_flush_active = '0;
   // }
   // flushing max result {
   flush_state_type st_amax_flush = flush_idle;
   flush_state_type st_amax_flush_n = flush_idle;
   logic unsigned [FLUSH_TIMER_W-1:0]    amax_flush_timer = '0;
   logic unsigned [FLUSH_TIMER_W-1:0]    amax_flush_timer_n = '0;
   logic                                 amax_flush_rqst = '0;
   logic                                 amax_flush_rqst_n = '0;
   logic                                 amax_flush_started = '0;
   logic                                 amax_flush_done = '0;
   logic                                 amax_dirty_content = '0;
   logic                                 amax_dirty_content_n = '0;
   logic                                 amax_flush_active = '0;
   // }
   // TODO: implement atomic address changing. Now only one address can be used by an atomic unit
   // TODO: consider the case when two atomic units work on the same global address

   // receivers interface {
   always_ff @(posedge clk) begin
      automatic logic unsigned [N_RECEIVERS_W-1:0] rcv_slctd_indx_unsigned = 0;
      rcv_half_select <= ~rcv_half_select;
      // stage 0:
      // select requesting receiver
      check_rqst <= 'b0;
      rcv_atomic_ack <= 'b0;
      for (int i = N_RECEIVERS/2-1; i >= 0; i--) begin
         rcv_slctd_indx_unsigned[N_RECEIVERS_W-1:1] = (N_RECEIVERS_W-1)'($unsigned(i));
         rcv_slctd_indx_unsigned[0] = rcv_half_select;
         if (rcv_atomic_rqst[$unsigned(rcv_slctd_indx_unsigned)]) begin
            rcv_slctd_indx <= $unsigned(rcv_slctd_indx_unsigned);
            rcv_atomic_ack[$unsigned(rcv_slctd_indx_unsigned)] <= 'b1;
            check_rqst <= 'b1;
            break;
         end
      end
      // stage 1
      // latch request
      rqst_type <= rcv_atomic_type[rcv_slctd_indx][2:0];
      rqst_gmem_addr <= rcv_gmem_addr[rcv_slctd_indx];
      check_rqst_d0 <= check_rqst;
      rcv_slctd_indx_d0 <= rcv_slctd_indx;

      // stage 2
      // check validety
      rcv_must_read <= '0;
      rcv_retire <= '0;
      aadd_exec <= '0;
      amax_exec <= '0;
      if (check_rqst_d0) begin
         case (rqst_type)
           I_AADD[2:0] : begin
              if (!aadd_addr_v || aadd_gmem_addr != rqst_gmem_addr) begin
                 if (!rcv_is_reading) begin
                    rcv_must_read[rcv_slctd_indx_d0] <= 'b1;
                    rcv_is_reading <= 'b1;
                 end
              end else begin
                 rcv_retire[rcv_slctd_indx_d0] <= 'b1;
                 aadd_exec <= 'b1;
              end
           end
           I_AMAX[2:0] : begin
              if (!amax_addr_v || amax_gmem_addr != rqst_gmem_addr) begin
                 if (!rcv_is_reading) begin
                    rcv_must_read[rcv_slctd_indx_d0] <= 'b1;
                    rcv_is_reading <= 'b1;
                 end
              end else begin
                 rcv_retire[rcv_slctd_indx_d0] <= 'b1;
                 amax_exec <= 'b1;
              end
           end
         endcase
      end // if (check_rqst_d0)
      rqst_val <= $unsigned(rcv_gmem_data[rcv_slctd_indx_d0]);
      // stage 3
      // wait for result
      aadd_exec_d0 <= aadd_exec;
      amax_exec_d0 <= amax_exec;

      // stage 4
      // forward result
      if (aadd_exec_d0) begin
         // if _d0 is removed then the atomic will giv back the new result instead of the old one
         atomic_rdData <= aadd_data_d0;
      end else begin
         atomic_rdData <= amax_data_d0;
      end

      // other tasks
      if ((aadd_addr_v && !aadd_addr_v_d0) || (amax_addr_v && !amax_addr_v_d0)) begin
         rcv_is_reading <= 'b0;
      end
      if (aadd_latch_gmem_rdData || amax_latch_gmem_rdData) begin
         gmem_rdData_ltchd <= gmem_rdData;
      end
   end
   // }
   // flushing amax {
   always_ff @(posedge clk) begin
      if (!nrst) begin
         st_amax_flush <= flush_idle;
         amax_flush_rqst <= '0;
         amax_dirty_content <= '0;
      end else begin
         st_amax_flush <= st_amax_flush_n;
         amax_flush_rqst <= amax_flush_rqst_n;
         amax_dirty_content <= amax_dirty_content_n;
      end
      amax_flush_timer <= amax_flush_timer_n;
   end // always_ff @ (posedge clk)
   always_comb begin
      st_amax_flush_n <= st_amax_flush;
      amax_flush_timer_n <= amax_flush_timer;
      amax_flush_rqst_n <= amax_flush_rqst;
      amax_dirty_content_n <= amax_dirty_content;
      case (st_amax_flush)
        flush_idle : begin
           amax_flush_timer_n <= 'b0;
           if (amax_exec || amax_dirty_content) begin
              st_amax_flush_n <= dirty;
           end
        end
        dirty : begin
           if (WGsDispatched_ltchd) begin
              amax_flush_timer_n <= amax_flush_timer + 1;
              if (amax_exec) begin
                 amax_flush_timer_n <= 'b0;
              end else if (amax_flush_timer == '1) begin
                 st_amax_flush_n <= flushing;
                 amax_flush_rqst_n <= 'b1;
                 amax_dirty_content_n <= '0;
              end
           end
        end // case: dirty
        flushing : begin
           if (amax_exec) begin
              amax_dirty_content_n <= 'b1;
           end
           if (amax_flush_started) begin
              st_amax_flush_n <= wait_flush_done;
              amax_flush_rqst_n <= '0;
           end
        end
        wait_flush_done : begin
           if (flush_done) begin
              st_amax_flush_n <= flush_idle;
           end
           if (amax_exec) begin
              amax_dirty_content_n <= 'b1;
           end
        end
      endcase
   end
   // }

   // flushing aadd {
   always_ff @(posedge clk) begin
      if (!nrst) begin
         st_aadd_flush <= flush_idle;
         aadd_flush_rqst <= '0;
         aadd_dirty_content <= '0;
      end else begin
         st_aadd_flush <= st_aadd_flush_n;
         aadd_flush_rqst <= aadd_flush_rqst_n;
         aadd_dirty_content <= aadd_dirty_content_n;
      end
      aadd_flush_timer <= aadd_flush_timer_n;
   end
   always_comb begin
      st_aadd_flush_n <= st_aadd_flush;
      aadd_flush_timer_n <= aadd_flush_timer;
      aadd_flush_rqst_n <= aadd_flush_rqst;
      aadd_dirty_content_n <= aadd_dirty_content;
      case (st_aadd_flush)
        flush_idle : begin
           aadd_flush_timer_n <= '0;
           if (aadd_exec || aadd_dirty_content) begin
              st_aadd_flush_n <= dirty;
           end
        end
        dirty : begin
           if (WGsDispatched_ltchd) begin
              aadd_flush_timer_n <= aadd_flush_timer + 1;
              if (aadd_exec) begin
                 aadd_flush_timer_n <= 'b0;
              end else if (aadd_flush_timer == '1) begin
                 st_aadd_flush_n <= flushing;
                 aadd_flush_rqst_n <= 'b1;
                 aadd_dirty_content_n <= 'b0;
              end
           end
        end // case: dirty
        flushing : begin
           if (aadd_exec) begin
              aadd_dirty_content_n <= 'b1;
           end
           if (aadd_flush_started) begin
              st_aadd_flush_n <= wait_flush_done;
              aadd_flush_rqst_n <= '0;
           end
        end
        wait_flush_done : begin
           if (flush_done) begin
              st_aadd_flush_n <= flush_idle;
           end
           if (aadd_exec) begin
              aadd_dirty_content_n <= 'b1;
           end
        end
      endcase
   end
   // }
   // atomic max {
   always_ff @(posedge clk) begin
      if (!nrst) begin
         amax_addr_v <= '0;
         st_amax <= atomic_idle;
      end else begin
         st_amax <= st_amax_n;
         amax_addr_v <= amax_addr_v_n;
      end
      amax_addr_v_d0 <= amax_addr_v;
      amax_gmem_addr <= amax_gmem_addr_n;
      amax_data <= amax_data_n;
      amax_data_d0 <= amax_data;
      amax_latch_gmem_rdData <= amax_latch_gmem_rdData_n;
   end // always_ff @ (posedge clk)
   always_comb begin
      automatic logic unsigned [GMEM_N_BANK_W-1:0] word_indx = 0;
      st_amax_n <= st_amax;
      amax_gmem_addr_n <= amax_gmem_addr;
      amax_data_n <= amax_data;
      amax_addr_v_n <= amax_addr_v;
      amax_latch_gmem_rdData_n <= '0;
      case (st_amax)
        atomic_idle : begin
           if (check_rqst_d0 && rqst_type == I_AMAX[2:0]) begin
              st_amax_n <= listening;
              amax_gmem_addr_n <= rqst_gmem_addr;
           end
        end
        listening : begin
           if (gmem_rdData_v_p0 && gmem_rdAddr_p0 == amax_gmem_addr[$high(amax_gmem_addr):N]) begin
              st_amax_n <= latch_gmem_data;
              amax_latch_gmem_rdData_n <= '1;
           end
        end
        latch_gmem_data : begin
           st_amax_n <= select_word;
        end
        select_word : begin
           word_indx = $unsigned(amax_gmem_addr[N-1:0]);
           amax_data_n <= $unsigned(gmem_rdData_ltchd[DATA_W*word_indx+:DATA_W]);
           amax_addr_v_n <= 'b1;
        end
        functioning : begin
           if ($signed(amax_data) < $signed(rqst_val)) begin
              amax_data_n <= rqst_val;
           end
           if (finish) begin
              st_amax_n <= atomic_idle;
              amax_addr_v_n <= '0;
           end
        end
      endcase
   end
   // }
   // atomic add {
   always_ff @(posedge clk) begin
      if (!nrst) begin
         aadd_addr_v <= '0;
         st_aadd <= atomic_idle;
      end else begin
         st_aadd <= st_aadd_n;
         aadd_addr_v <= aadd_addr_v_n;
      end
      aadd_addr_v_d0 <= aadd_addr_v;
      aadd_gmem_addr <= aadd_gmem_addr_n;
      aadd_data <= aadd_data_n;
      aadd_data_d0 <= aadd_data;
      aadd_latch_gmem_rdData <= aadd_latch_gmem_rdData_n;
   end
   always_comb begin
      automatic logic unsigned [GMEM_N_BANK_W-1:0] word_indx = 0;
      st_aadd_n <= st_aadd;
      aadd_gmem_addr_n <= aadd_gmem_addr;
      aadd_data_n <= aadd_data;
      aadd_addr_v_n <= aadd_addr_v;
      aadd_latch_gmem_rdData_n <= '0;

      case (st_aadd)
        atomic_idle : begin
           if (check_rqst_d0 && rqst_type == I_AADD[2:0]) begin
              st_aadd_n <= listening;
              aadd_gmem_addr_n <= rqst_gmem_addr;
           end
        end
        listening : begin
           if (gmem_rdData_v_p0 && gmem_rdAddr_p0 == aadd_gmem_addr[$high(aadd_gmem_addr):N]) begin
              st_aadd_n <= latch_gmem_data;
              aadd_latch_gmem_rdData_n <= 'b1;
           end
        end
        latch_gmem_data : begin
           st_aadd_n <= select_word;
        end
        select_word : begin
           word_indx = $unsigned(aadd_gmem_addr[N-1:0]);
           aadd_data_n <= $unsigned(gmem_rdData_ltchd[DATA_W*word_indx+:DATA_W]);
           st_aadd_n <= functioning;
           aadd_addr_v_n <= 'b1;
        end
        functioning : begin
           if (aadd_exec) begin
              aadd_data_n <= aadd_data + rqst_val;
           end
           if (finish) begin
              st_aadd_n <= atomic_idle;
              aadd_addr_v_n <= '0;
           end
        end
      endcase
   end
   // }
   // flushing {
   always_ff @(posedge clk) begin
      if (nrst) begin
         if (finish) begin
            WGsDispatched_ltchd <= 'b0;
         end else if (WGsDispatched) begin
            WGsDispatched_ltchd <= 'b1;
         end
      end else begin
         WGsDispatched_ltchd <= 'b0;
      end

      if (st_aadd_flush == flush_idle && st_amax_flush == flush_idle) begin
         atomic_can_finish <= 'b1;
      end else begin
         atomic_can_finish <= 'b0;
      end

      flush_v <= (aadd_flush_rqst || amax_flush_rqst) && ~(flush_ack || flush_ack_d0);
      flush_ack_d0 <= flush_ack;
      aadd_flush_started <= '0;
      amax_flush_started <= '0;
      aadd_flush_active <= '0;
      amax_flush_active <= '0;

      if (!flush_ack) begin
         if (aadd_flush_rqst) begin
            flush_gmem_addr <= aadd_gmem_addr;
            flush_data <= aadd_data;
            aadd_flush_active <= 'b1;
         end else if (amax_flush_rqst) begin
            flush_gmem_addr <= amax_gmem_addr;
            flush_data <= amax_data;
            amax_flush_active <= 'b1;
         end
      end else begin
         if (aadd_flush_active) begin
            aadd_flush_started <= 'b1;
         end else begin
            amax_flush_started <= 'b1;
         end
      end
   end
   // }

endmodule
