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

   int                                                              delete_st = 0;
   int                                                              empty_st = 0;

   generate begin for (genvar i = 0; i < 2**N_STATIONS_W; i++) begin
      for (genvar j = 0; j < N_OPERANDS; j++) begin
         always_comb begin
            station_filled_n[i][j] <= station_filled[i][j];
            station_data_n[i][j] <= station_data[i][j];
            if ((i == empty_st) && i_valid && i_ready) begin
               station_filled_n[i][j] <= i_filled[j];
               station_data_n[i][j] <= i_data[j*(RSV_ID_W+DATA_W)+:(RSV_ID_W+DATA_W)];
            end else if ((i == delete_st) && o_valid && o_ready) begin
               station_filled_n[i][j] <= 'b0;
               station_data_n[i][j] <= 'b0;
            end else if (cdb_valid) begin
               if (station_valid[i] && ~station_filled[i] && cdb_valid &&
                   station_data[i][j][DATA_W+:RSV_ID_W] == cdb[DATA_W+:RSV_ID_W]) begin
                  station_filled_n[i][j] <= 'b1;
                  station_data_n[i][j] <= cdb;
               end
            end
         end
      end

      always_comb begin
         station_valid_n[i] <= station_valid[i];
         station_ordered_n[i] <= station_ordered[i];
         station_n[i] <= station[i];
         if ((i == empty_st) && i_valid && i_ready) begin
            // new entry
            station_valid_n[i] <= 'b1;
            station_ordered_n[i] <= 'b1; // TODO
            station_n[i] <= {i_data[N_OPERANDS*(RSV_ID_W+DATA_W)+:RSV_ID_W+INSTR_W], {(RSV_ID_W){1'b0}}};
         end else if ((i == delete_st) && o_valid && o_ready) begin
            // delete entry
            station_valid_n[i] <= 'b0;
            station_ordered_n[i] <= 'b0;
            station_n[i] <= 'b0;
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

         // check whether the operands are served
         o_valid <= station_valid_n[delete_st] &
                    station_ordered_n[delete_st] &
                    (&station_filled_n[delete_st]);
         o_data[N_OPERANDS*DATA_W+:(RSV_ID_W+INSTR_W)] <= station_n[delete_st][RSV_ID_W+:RSV_ID_W+INSTR_W];
         for (int i = 0; i < N_OPERANDS; i++) begin
            o_data[i*DATA_W+:DATA_W] <= station_data_n[delete_st][i];
         end

         for (int i = 0; i < 2**N_STATIONS_W; i++) delete_check : begin
            delete_st <= i;
            if (station_valid_n[i] && station_ordered_n[i]) begin
               break;
            end
         end

         i_ready <= 'b0;
         for (int i = 0; i < 2**N_STATIONS_W; i++) ready_check : begin
            empty_st <= i;
            if (!station_valid_n[i]) begin // valid
               i_ready <= 'b1;
               break;
            end
         end
      end else begin
         station_valid <= 'b0;
         station_ordered <= 'b0;
         station_filled <= 'b0;
         station <= 'b0;
         station_data <= 'b0;
         o_valid <= 'b0;
      end
   end

endmodule
