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
    output logic                                                    pred_miss,
    output logic [CRAM_ADDR_W-1:0]                                  pred_miss_dst,
    // reset
    input logic                                                     nrst
    );

   wire [INSTR_W-1:0]                                               opcode;
   wire [DATA_W-1:0]                                                a1;
   wire [DATA_W-1:0]                                                a2;
   logic                                                            condition = '0;
   wire                                                             pred_condition;
   wire [DATA_W-1:0]                                                dst;

   wire [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0]                  calc_n;
   logic [RSV_ID_W+INSTR_W+N_OPERANDS*(DATA_W)-1:0]                 calc = '0;;
   // inner signals
   wire                                                             calc_valid_n;
   logic                                                            calc_valid = 'b0;
   wire                                                             calc_ready;

   assign opcode = calc[2*DATA_W+:INSTR_W];
   assign a1 = calc[3*DATA_W+:DATA_W];
   assign a2 = calc[2*DATA_W+:DATA_W];
   assign pred_condition = calc[1*DATA_W];
   assign dst = calc[0*DATA_W+:DATA_W];
   assign o_valid = calc_valid;
   assign calc_ready = 'b1;

   assign take_flag = 'b0;
   assign rob_clear = 'b0;
   assign branch_miss = 'b0;

   always_comb begin
      case (opcode)
        I_BLT :
          condition <= (a1 > a2) ? 'b1 : 'b0;
        I_BEQ :
          condition <= (a1 == a2) ? 'b1 : 'b0;
        default:
          condition <= 'b0;
      endcase
   end

   assign pred_miss_dst = dst[CRAM_ADDR_W-1:0];
   assign pred_miss = condition ^ pred_condition;

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
      .i_ordered('b1),
      .i_ready(i_ready),

      .o_valid(calc_valid_n),
      .o_data(calc_n),
      .o_ready(calc_ready),

      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst)
      );

endmodule
