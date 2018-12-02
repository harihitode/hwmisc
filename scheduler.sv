`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

// instruction scheduler

module scheduler
  (
   input logic                    clk,
   input logic                    ce, // for halt

   // branch prediction
   input logic                    take_flag,
   // missed prediction
   input logic                    pred_miss,
   input logic [CRAM_ADDR_W-1:0]  pred_miss_dst,

   // cram
   input logic [DATA_W-1:0]       cram_data,
   output logic [CRAM_ADDR_W-1:0] cram_addr,

   // to core
   output logic [CRAM_ADDR_W-1:0] o_current_pc,
   output logic [DATA_W-1:0]      o_current_inst,
   output logic [CRAM_ADDR_W-1:0] o_taken_pc,
   output logic [CRAM_ADDR_W-1:0] o_untaken_pc,

   input                          nrst
   );

   logic [CRAM_ADDR_W-1:0]        cram_addrB = '0;

   typedef struct packed {
      logic [CRAM_ADDR_W-1:0] pc;
      logic       take_flag;
      logic [DATA_W-1:0]      cram_data;
   } lut_t;

   lut_t lut1 = '0;
   lut_t lut1B = 0;
   lut_t lut2 = '0;
   lut_t lut2B = 0;

   always_comb begin
      if (pred_miss) begin
         lut1 <= '0;
      end else if (!ce) begin
         lut1 <= lut1B;
      end else begin
         lut1 <= {cram_addrB,
                  take_flag,
                  cram_data};
      end
   end // always_comb

   always_comb begin
      if (pred_miss) begin
         lut2 <= '0;
      end else if (!ce) begin
         lut2 <= lut2B;
      end else begin
         lut2 <= lut1;
      end
   end

   wire                                  branch_flag;
   assign branch_flag = (cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BLE ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BLEI ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BLT ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BLTF ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BLTI ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BEQ ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BEQF ||
                         cram_data[DATA_W-1:DATA_W-INSTR_W] == I_BEQI
                         ) ? 'b1 : 'b0;

   always_comb begin
      if (!nrst) begin
         cram_addr <= 'b0;
      end else if (pred_miss) begin
         cram_addr <= pred_miss_dst;
      end else if (!ce) begin
         cram_addr <= cram_addrB;
      end else if (cram_data[DATA_W-1:DATA_W-INSTR_W] == I_JMP) begin
         cram_addr <= cram_data[21:0];
      end else if (branch_flag && take_flag) begin
         cram_addr <= cram_data[14:0];
      end else begin
         cram_addr <= cram_addrB + 'b1;
      end
   end // always_comb

   assign o_current_pc   = lut2B.pc;
   assign o_current_inst = lut2B.cram_data;

   always_comb begin
      if (branch_flag) begin
         if (take_flag) begin
            o_taken_pc   <= lut2B.cram_data[14:0];
            o_untaken_pc <= lut2B.pc + 1;
         end else begin
            o_taken_pc   <= lut2B.pc + 1;
            o_untaken_pc <= lut2B.cram_data[14:0];
         end
      end else begin
         o_taken_pc   <= '0;
         o_untaken_pc <= '0;
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         lut1B <= lut1;
         lut2B <= lut2;
         cram_addrB <= cram_addr;
      end else begin
         lut1B <= '0;
         lut2B <= '0;
         cram_addrB <= '0;
      end
   end

endmodule
