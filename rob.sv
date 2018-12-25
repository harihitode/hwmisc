`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module reorder_buffer
  #(parameter ROB_PORT_W = 6) // integer regs 3 + float regs 3
   (
    // reserve signals
    input logic                                        clk,
    input logic                                        i_valid,
    output logic                                       i_ready,
    output logic [RSV_ID_W-1:0]                        i_rsv_id,
    input logic [REG_ADDR_W-1:0]                       i_dst_reg,
    input logic                                        i_no_wait, // store, jump etc
    input logic [INSTR_W-1:0]                          i_opcode,

    // rob read port
    input logic [ROB_PORT_W-1:0][RSV_ID_W-1:0]         rob_id,
    output logic [ROB_PORT_W-1:0][RSV_ID_W+DATA_W-1:0] rob_data,
    output logic [ROB_PORT_W-1:0]                      rob_data_filled,

    // from branch unit
    input logic                                        rob_clear,

    // to committer
    output logic                                       o_valid,
    output                                             station_t o_commit_data,
    input logic                                        o_ready,

    input logic                                        cdb_valid,
    input logic                                        cdb_exception,
    input logic [CDB_W-1:0]                            cdb,

    input logic                                        nrst
   );

   station_t station_n [2**N_ROB_W-1:0] = '{default:'0};
   station_t station [2**N_ROB_W-1:0] = '{default:'0};
   station_t new_station [2**N_ROB_W-1:0] = '{default:'0};
   station_t update_station [2**N_ROB_W-1:0] = '{default:'0};
   station_t head_station = '0;

   logic [2**N_ROB_W-1:0]                              rob_reserve;
   logic [2**N_ROB_W-1:0]                              rob_release;

   logic [N_ROB_W-1:0]                                 rob_tail = 'h0;
   logic [N_ROB_W-1:0]                                 rob_tail_n;
   logic [N_ROB_W-1:0]                                 rob_head = 'h0;
   logic [N_ROB_W-1:0]                                 rob_head_n;

   assign o_valid = head_station.valid & head_station.ready;
   always_comb head_station <= station[$unsigned(rob_head)];
   assign i_rsv_id = rob_tail;
   assign i_ready = (head_station.valid && (rob_head == rob_tail)) ? 'b0 : 'b1;
   assign o_commit_data = head_station;

   always_comb begin
      rob_reserve <= 'b0;
      if (i_valid && i_ready) begin
         rob_reserve[rob_tail] <= 'b1;
      end
   end

   always_comb begin
      rob_release <= 'b0;
      if (o_valid && o_ready) begin
         rob_release[rob_head] <= 'b1;
      end
   end

   // ROB data read {
   generate begin for (genvar i = 0; i < ROB_PORT_W; i++) begin
      always_latch begin
         for (int j = 0; j < 2**N_ROB_W; j++) begin
            if (j == rob_id[i]) begin
               rob_data[i] <= {RSV_ID_W'(j), station[j].content};
               rob_data_filled[i] <= station[j].ready;
            end
         end
      end
   end end
   endgenerate
   // }

   // station update {
   generate begin for (genvar i = 0; i < 2**N_ROB_W; i++) begin
      always_comb begin
         // reserve new rob station {
         new_station[i].station_id <= (N_STATIONS_W)'($unsigned(i));
         new_station[i].valid      <= 'b1;
         new_station[i].ready      <= i_no_wait;
         new_station[i].dst_reg    <= i_dst_reg;
         new_station[i].opcode     <= i_opcode;
         new_station[i].content    <= 'b0;
         // }

         // update rob stations {
         if (rob_clear) begin
            update_station[i].valid <= 'b0;
         end else begin
            update_station[i].valid <= station[i].valid;
         end
         update_station[i].station_id <= station[i].station_id;
         update_station[i].dst_reg <= station[i].dst_reg;
         update_station[i].opcode <= station[i].opcode;

         if (cdb_valid && $unsigned(cdb[DATA_W+:RSV_ID_W]) == i) begin
            update_station[i].ready <= 'b1;
            update_station[i].content <= cdb[DATA_W-1:0];
         end else begin
            update_station[i].ready <= station[i].ready;
            update_station[i].content <= station[i].content;
         end
         // }

         if (rob_release[i]) begin
            station_n[i] <= '0;
         end else if (rob_reserve[i]) begin
            station_n[i] <= new_station[i];
         end else begin
            station_n[i] <= update_station[i];
         end
      end // always_comb

      always_ff @(posedge clk) begin
         if (nrst) begin
            station[i] <= station_n[i];
         end else begin
            station[i] <= '0;
         end
      end
   end end
   endgenerate
   // }

   always_comb head_countup : begin
      if (o_valid && o_ready) begin
         if (rob_head == 2**N_ROB_W-1) begin
            rob_head_n <= 0;
         end else begin
            rob_head_n <= rob_head + 'b1;
         end
      end else begin
         rob_head_n <= rob_head;
      end
   end // always_comb

   always_comb tail_countup : begin
      if (i_valid && i_ready) begin
         if (rob_tail == 2**N_ROB_W-1) begin
            rob_tail_n <= 0;
         end else begin
            rob_tail_n <= rob_tail + 'b1;
         end
      end else begin
         rob_tail_n <= rob_tail;
      end
   end // always_comb

   always_ff @(posedge clk) begin
      if (nrst) begin
         rob_head <= rob_head_n;
         rob_tail <= rob_tail_n;
      end else begin
         rob_head <= 'h0;
         rob_tail <= 'h0;
      end
   end // always_ff @ (posedge clk)

endmodule
