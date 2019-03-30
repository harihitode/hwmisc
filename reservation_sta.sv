`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module reservation_station
  #(parameter N_OPERANDS = 1,
    parameter N_STATIONS_W = 4
    )
   (
    input logic                                                     clk,

    input logic                                                     i_valid,
    input logic                                                     i_ordered,
    input logic [RSV_ID_W+INSTR_W+N_OPERANDS*(RSV_ID_W+DATA_W)-1:0] i_data,
    input logic [N_OPERANDS-1:0]                                    i_filled, // data filled
    output logic                                                    i_ready,

    output logic                                                    o_valid,
    output logic [RSV_ID_W+INSTR_W+N_OPERANDS*DATA_W-1:0]           o_data,
    input logic                                                     o_ready, // halt

    input                                                           cdb_valid,
    input [CDB_W-1:0]                                               cdb,

    input logic                                                     nrst
    );

   typedef struct                                                   packed {
      logic                                                         valid;
      logic                                                         ordered;
      logic [N_STATIONS_W-1:0]                                      ordered_st_id;
      logic [RSV_ID_W-1:0]                                          rob_id;
      logic [INSTR_W-1:0]                                           opcode;
      logic [N_OPERANDS-1:0]                                        filled;
      logic [N_OPERANDS-1:0][RSV_ID_W-1:0]                          data_rsv_id;
      logic [N_OPERANDS-1:0][DATA_W-1:0]                            data;
   } rsv_station_t;

   // dest_rob_if, opcode, ordered_tag

   rsv_station_t [2**N_STATIONS_W-1:0] station = '0;
   rsv_station_t [2**N_STATIONS_W-1:0] station_n = '0;

   int                                                              delete_st = 0;
   int                                                              empty_st = 0;

   logic [N_STATIONS_W-1:0]                                         ordered_id = 'b0;
   logic                                                            ordered = 'b0;

   always_ff @(posedge clk) begin
      if (nrst) begin
         if (i_valid && i_ready && i_ordered) begin
            ordered_id <= ordered_id + 'b1;
         end
      end else begin
         ordered_id <= 'b0;
      end
   end

   // TODO
   logic [2**N_STATIONS_W-1:0] ordered_v = 'b0;
   generate for (genvar i = 0; i < 2**N_STATIONS_W; i++) begin
      always_comb begin
         ordered_v[i] <= station[i].valid ? ~i_ordered : 'b1;
      end
   end endgenerate
   always_comb begin
      ordered <= &ordered_v;
   end

   generate begin
      for (genvar i = 0; i < 2**N_STATIONS_W; i++) begin
         for (genvar j = 0; j < N_OPERANDS; j++) begin
            always_comb begin
               station_n[i].filled[j] <= station[i].filled[j];
               station_n[i].data_rsv_id[j] <= station[i].data_rsv_id[j];
               station_n[i].data[j] <= station[i].data[j];
               if ((i == empty_st) && i_valid && i_ready) begin
                  station_n[i].filled[j] <= i_filled[j];
                  station_n[i].data_rsv_id[j] <= i_data[j*(RSV_ID_W+DATA_W)+DATA_W+:RSV_ID_W];
                  station_n[i].data[j] <= i_data[j*(RSV_ID_W+DATA_W)+:DATA_W];
               end else if ((i == delete_st) && o_valid && o_ready) begin
                  station_n[i].filled[j] <= 'b0;
                  station_n[i].data_rsv_id[j] <= 'b0;
                  station_n[i].data[j] <= 'b0;
               end else if (cdb_valid) begin
                  if (station[i].valid && ~station[i].filled[j] && cdb_valid &&
                      station[i].data_rsv_id[j] == cdb[DATA_W+:RSV_ID_W]) begin
                     station_n[i].filled[j] <= 'b1;
                     station_n[i].data_rsv_id[j] <= cdb[DATA_W+:RSV_ID_W];
                     station_n[i].data[j] <= cdb[0+:DATA_W];
                  end
               end
            end
         end

         always_comb begin
            station_n[i].valid <= station[i].valid;
            station_n[i].ordered <= station[i].ordered;
            station_n[i].ordered_st_id <= station[i].ordered_st_id;
            station_n[i].opcode <= station[i].opcode;
            station_n[i].rob_id <= station[i].rob_id;
            if ((i == empty_st) && i_valid && i_ready) begin
               // new entry
               station_n[i].valid <= 'b1;
               if (ordered_id ==
                   (N_STATIONS_W)'(station[delete_st].ordered_st_id + 'b1)
                   && o_valid && o_ready) begin
                  station_n[i].ordered <= 'b1;
               end else begin
                  station_n[i].ordered <= ordered;
               end
               // the last RSV_ID is dependency of ordering
               station_n[i].opcode <= i_data[N_OPERANDS*(RSV_ID_W+DATA_W)+:INSTR_W];
               station_n[i].rob_id <= i_data[N_OPERANDS*(RSV_ID_W+DATA_W)+INSTR_W+:RSV_ID_W];
               station_n[i].ordered_st_id <= ordered_id;
            end else if ((i == delete_st) && o_valid && o_ready) begin
               // delete entry
               station_n[i].valid <= '0;
               station_n[i].ordered <= '0;
               station_n[i].ordered_st_id <= '0;
               station_n[i].opcode <= '0;
               station_n[i].rob_id <= '0;
            end else if (station[i].ordered_st_id ==
                         (N_STATIONS_W)'(station[delete_st].ordered_st_id + 'b1)
                         && o_valid && o_ready) begin
               station_n[i].ordered <= 1'b1;
            end
         end
      end
   end
   endgenerate

   always_comb begin
      // check whether the operands are served
      o_valid <= station[delete_st].valid &
                 station[delete_st].ordered &
                 (&station[delete_st].filled);
      o_data[N_OPERANDS*DATA_W+:(RSV_ID_W+INSTR_W)] <= {station[delete_st].rob_id,
                                                        station[delete_st].opcode};
   end

   generate for (genvar i = 0; i < N_OPERANDS; i++) begin
      always_comb begin
         o_data[i*DATA_W+:DATA_W] <= station[delete_st].data[i];
      end
   end endgenerate

   int delete_st_v [2**N_STATIONS_W:0] = '{default: 0};
   generate for (genvar i = 0; i < 2**N_STATIONS_W; i++) delete_chk : begin
      always_comb begin
         if (station[i].valid && station[i].ordered &&
             (&station[i].filled)) begin
            delete_st_v[i+1] <= $unsigned(i);
         end else begin
            delete_st_v[i+1] <= delete_st_v[i];
         end
      end
   end endgenerate
   always_comb begin
      delete_st <= delete_st_v[2**N_STATIONS_W];
   end

   int empty_st_v [2**N_STATIONS_W:0] = '{default: 0};
   logic [2**N_STATIONS_W-1:0] i_ready_v = 'b0;
   generate for (genvar i = 0; i < 2**N_STATIONS_W; i++) ready_chk : begin
      always_comb begin
         if (!station[i].valid) begin
            empty_st_v[i+1] <= $unsigned(i);
            i_ready_v[i] <= 'b1;
         end else begin;
            empty_st_v[i+1] <= empty_st_v[i];
            i_ready_v[i] <= 'b0;
         end
      end
   end endgenerate
   always_comb begin
      empty_st <= empty_st_v[2**N_STATIONS_W];
      i_ready <= |i_ready_v;
   end

   always_ff @(posedge clk) update : begin
      if (nrst) begin
         station <= station_n;
      end else begin
         station <= 'b0;
      end
   end

endmodule
