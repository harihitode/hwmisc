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

   logic [2**N_STATIONS_W-1:0]                                      station_valid_n = '0;
   logic [2**N_STATIONS_W-1:0]                                      station_valid = '0;
   logic [2**N_STATIONS_W-1:0]                                      station_ordered_n = '0;
   logic [2**N_STATIONS_W-1:0]                                      station_ordered = '0;
   logic [2**N_STATIONS_W-1:0][N_OPERANDS-1:0]                      station_filled_n = '0;
   logic [2**N_STATIONS_W-1:0][N_OPERANDS-1:0]                      station_filled = '0;
   // dest_rob_if, opcode, ordered_tag
   logic [2**N_STATIONS_W-1:0][RSV_ID_W+INSTR_W+RSV_ID_W-1:0]       station_n = '0;
   logic [2**N_STATIONS_W-1:0][RSV_ID_W+INSTR_W+RSV_ID_W-1:0]       station = '0;

   logic [2**N_STATIONS_W-1:0][N_OPERANDS-1:0][RSV_ID_W+DATA_W-1:0] station_data_n = '0;
   logic [2**N_STATIONS_W-1:0][N_OPERANDS-1:0][RSV_ID_W+DATA_W-1:0] station_data = '0;

   int                                       delete_st = 0;
   int                                       empty_st = 0;

   assign o_data[N_OPERANDS*DATA_W+:(RSV_ID_W+INSTR_W)] = station[delete_st][RSV_ID_W+:RSV_ID_W+INSTR_W];

   generate begin for (genvar i = 0; i < N_OPERANDS; i++) begin
      assign o_data[i*DATA_W+:DATA_W] = station_data[delete_st][i];
   end end
   endgenerate

   always_latch delete_check : begin
      for (int i = 0; i < 2**N_STATIONS_W; i++) begin
         delete_st <= i;
         if (station_valid[i] && station_ordered[i]) begin
            break;
         end
      end
   end // always_latch

   // check whether the operands are served
   always_comb filled_check : begin
      o_valid <= station_valid[delete_st] &
                 station_ordered[delete_st] &
                 (&station_filled[delete_st]);
   end

   always_comb ready_check : begin
      automatic logic station_full = 'b1;
      for (int i = 0; i < 2**N_STATIONS_W; i++) begin
         empty_st <= i;
         if (!station_valid[i]) begin // valid
            station_full = 'b0;
            break;
         end
      end
      i_ready <= ~station_full;
   end // always_comb

   generate begin for (genvar i = 0; i < 2**N_STATIONS_W; i++) begin
      always_latch begin
         if (i == empty_st && i_valid && i_ready) begin
            // new entry
            station_valid_n[i] <= 'b1;
            station_ordered_n[i] <= 'b1; // TODO
            station_n[i] <= {i_data[N_OPERANDS*(RSV_ID_W+DATA_W)+:RSV_ID_W+INSTR_W], {(RSV_ID_W){1'b0}}};
            station_filled_n[i] <= i_filled;
            station_data_n[i] <= i_data[0+:N_OPERANDS*(RSV_ID_W+DATA_W)];
         end else if (i == delete_st && o_valid && o_ready) begin
            // delete entry
            station_valid_n[i] <= 'b0;
            station_ordered_n[i] <= 'b0;
            station_n[i] <= 'b0;
            station_filled_n[i] <= 'b0;
            station_data_n[i] <= 'b0;
         end else if (cdb_valid) begin
            for (int j = 0; j < N_OPERANDS; j++) begin
               if (station_valid[i] && ~station_filled[i] && cdb_valid &&
                   station_data[i][j][DATA_W+:RSV_ID_W] == cdb[DATA_W+:RSV_ID_W]) begin
                  station_filled_n[i][j] <= 'b1;
                  station_data_n[i][j] <= cdb;
               end
            end
         end
      end
   end end
   endgenerate

   always_ff @(posedge clk) update : begin
      if (nrst) begin
         station_valid <= station_valid_n;
         station_ordered <= station_ordered_n;
         station_filled <= station_filled_n;
         station <= station_n;
         station_data <= station_data_n;
      end else begin
         station_valid <= 'b0;
         station_ordered <= 'b0;
         station_filled <= 'b0;
         station <= 'b0;
         station_data <= 'b0;
      end
   end

endmodule
