`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module alu
  #(localparam N_OPERANDS = 2)
   (
    input logic                                                     clk,

    input logic                                                     i_valid,
    input logic [RSV_ID_W+INSTR_W+N_OPERANDS*(RSV_ID_W+DATA_W)-1:0] i_data,
    input logic [N_OPERANDS-1:0]                                    i_filled,
    output logic                                                    i_ready,

    input logic [CDB_W-1:0]                                         cdb,
    input logic                                                     cdb_valid,

    output logic [CDB_W-1:0]                                        o_cdb,
    output logic                                                    o_valid,
    input logic                                                     o_ready,

    input logic                                                     nrst
    );

   wire [INSTR_W-1:0] opcode;
   wire [DATA_W-1:0]  a1;
   wire [DATA_W-1:0]  a2;
   wire [DATA_W-1:0]  a2_negative;
   logic [DATA_W-1:0] pre_ret = '0;
   logic [DATA_W-1:0] a_shift = '0;

   wire [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0] calc_n;
   logic [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0] calc = '0;;
   // inner signals
   wire                                             calc_valid_n;
   logic                                            calc_valid = 'b0;
   wire                                             calc_ready;

   assign opcode = calc[2*DATA_W+:INSTR_W];
   assign a1 = calc[1*DATA_W+:DATA_W];
   assign a2 = calc[0*DATA_W+:DATA_W];
   assign a2_negative = ~a2 + 'h1;
   assign o_valid = calc_valid;
   assign calc_ready = (calc_valid && o_ready) || ~calc_valid;

   always_comb begin
      case (opcode)
        I_SL, I_SRL :
          pre_ret <= a1 << a2;
        I_SRA :
          pre_ret <= $signed(a1) >> a2;
        I_SRL :
          pre_ret <= $unsigned(a1) >> a2;
        I_ADD, I_ADDI :
          pre_ret <= a1 + a2;
        I_SUB, I_SUBI :
          pre_ret <= a1 + a2_negative;
        I_SAVE :
          pre_ret <= a1 + 'd2;
        I_AND :
          pre_ret <= a1 & a2;
        I_OR :
          pre_ret <= a1 | a2;
        I_XOR :
          pre_ret <= a1 ^ a2;
        I_SETI1 :
          pre_ret <= {16'h0000, a2[15:0]};
        I_SETI2 :
          pre_ret <= {a2[15:0], a1[15:0]};
        default:
          pre_ret <= 'h0;
      endcase
   end // always_comb

   always_comb begin
      o_cdb <= {calc[2*DATA_W+INSTR_W+:RSV_ID_W], pre_ret};
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         calc <= calc_n;
         calc_valid <= calc_valid_n;
      end else begin
         calc <= 'b0;
         calc_valid <= 'b0;
      end
   end

   reservation_station
     #(.N_OPERANDS(N_OPERANDS),
       .N_STATIONS_W(2))
   rsv_sta
     (
      .clk(clk),
      .i_valid(i_valid),
      .i_data(i_data),
      .i_filled(i_filled),
      .i_ordered('b0),
      .i_ready(i_ready),

      .o_valid(calc_valid_n),
      .o_data(calc_n),
      .o_ready(calc_ready),

      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst)
      );

endmodule
