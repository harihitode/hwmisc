`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module branch_unit
  #(localparam N_OPERANDS = 3)
   (
    input logic                                                     clk,
    // reserve
    input logic [RSV_ID_W+INSTR_W+N_OPERANDS*(RSV_ID_W+DATA_W)-1:0] i_data,
    input logic                                                     i_valid,
    input logic [N_OPERANDS-1:0]                                    i_filled,
    input logic                                                     i_condition,
    output logic                                                    i_ready,
    // from CDB
    input logic [CDB_W-1:0]                                         cdb,
    input logic                                                     cdb_valid,
    // to scheduler
    output logic                                                    take_flag,
    // to ROB
    input logic                                                     commit_valid,
    input                                                           station_t commit_data,
    // branch miss
    input logic [INSTR_W-1:0]                                       commit_opcode,
    input logic [N_STATIONS_W-1:0]                                  commit_id,
    output logic                                                    pred_condition,
    output logic                                                    true_condition,
    output logic                                                    pred_miss,
    // to cdb
    output logic [CDB_W-1:0]                                        o_cdb,
    output logic                                                    o_valid,
    input logic                                                     o_ready,
    input logic                                                     clear,
    // reset
    input logic                                                     nrst
    );

   wire [INSTR_W-1:0]                                               opcode;
   wire [DATA_W-1:0]                                                a1;
   wire [DATA_W-1:0]                                                a2;
   wire [DATA_W-1:0]                                                dst;

   wire [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0]                  calc_n;
   wire [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0]                  calc;
   // inner signals
   wire                                                             calc_valid_n;
   wire                                                             calc_valid;
   wire                                                             calc_ready_n;
   wire                                                             calc_ready;

   logic [2**N_STATIONS_W-1:0]                                      pred_conditions = 'b0;
   logic [2**N_STATIONS_W-1:0]                                      true_conditions = 'b0;

   assign pred_condition = pred_conditions[commit_id];
   assign true_condition = true_conditions[commit_id];

   assign opcode = calc[3*DATA_W+:INSTR_W];
   assign a1 = calc[2*DATA_W+:DATA_W];
   assign a2 = calc[1*DATA_W+:DATA_W];
   assign dst = calc[0*DATA_W+:DATA_W];
   assign o_valid = calc_valid;
   assign calc_ready = o_ready;

   assign take_flag = 'b0; // TODO

   always_comb begin
      o_cdb <= {calc[N_OPERANDS*DATA_W+INSTR_W+:RSV_ID_W], dst};
   end

   always_ff @(posedge clk) begin
      case (opcode)
        I_BLT :
          true_conditions[calc[3*DATA_W+INSTR_W+:RSV_ID_W]] <= (a1 < a2) ? 'b1 : 'b0;
        I_BEQ :
          true_conditions[calc[3*DATA_W+INSTR_W+:RSV_ID_W]] <= (a1 == a2) ? 'b1 : 'b0;
      endcase
   end

   always_ff @(posedge clk) begin
      if (nrst & ~clear) begin
         pred_conditions[N_OPERANDS*(RSV_ID_W+DATA_W)+INSTR_W+RSV_ID_W] <= i_condition;
      end else begin
         pred_conditions <= 'b0;
      end
   end

   always_comb begin
      if (commit_valid) begin
         if (commit_opcode == I_JMP) begin
            pred_miss <= 'b0;
         end else if (commit_opcode == I_JMPR) begin
            pred_miss <= 'b1;
         end else if (commit_opcode == I_BLT ||
                      commit_opcode == I_BEQ) begin
            pred_miss <= true_conditions[commit_id] ^ pred_conditions[commit_id];
         end else begin
            pred_miss <= 'b0;
         end
      end else begin
         pred_miss <= 'b0;
      end
   end

   fifo
     #(.FIFO_DEPTH_W(0),
       .DATA_W(RSV_ID_W+INSTR_W+N_OPERANDS*DATA_W))
   pre_calculation_buffer
     (
      .clk(clk),

      .a_data(calc_n),
      .a_valid(calc_valid_n),
      .a_ready(calc_ready_n),
      .b_data(calc),
      .b_valid(calc_valid),
      .b_ready(calc_ready),

      .nrst(nrst & ~clear)
      );

   reservation_station
     #(.N_OPERANDS(N_OPERANDS),
       .N_STATIONS_W(2))
   rsv_sta
     (
      .clk(clk),
      .i_valid(i_valid),
      .i_data(i_data),
      .i_filled(i_filled),
      .i_ordered('b1),
      .i_ready(i_ready),

      .o_valid(calc_valid_n),
      .o_data(calc_n),
      .o_ready(calc_ready),

      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst & ~clear)
      );

endmodule
