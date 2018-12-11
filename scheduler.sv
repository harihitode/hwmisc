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
   // Slave Interface Read Address Ports
   output logic [3:0]             s_cram_arid,
   output logic [31:0]            s_cram_araddr,
   output logic [7:0]             s_cram_arlen,
   output logic [2:0]             s_cram_arsize,
   output logic [1:0]             s_cram_arburst,
   output logic [0:0]             s_cram_arlock,
   output logic [3:0]             s_cram_arcache,
   output logic [2:0]             s_cram_arprot,
   output logic [3:0]             s_cram_arqos,
   output logic                   s_cram_arvalid,
   input logic                    s_cram_arready,

   // Slave Interface Read Data Ports
   output logic                   s_cram_rready,
   input logic [3:0]              s_cram_rid,
   input logic [31:0]             s_cram_rdata,
   input logic [1:0]              s_cram_rresp,
   input logic                    s_cram_rlast,
   input logic                    s_cram_rvalid,

   // to core
   output logic [CRAM_ADDR_W-1:0] o_current_pc,
   output logic [DATA_W-1:0]      o_current_inst,
   output logic [CRAM_ADDR_W-1:0] o_taken_pc,
   output logic [CRAM_ADDR_W-1:0] o_untaken_pc,

   input                          nrst
   );

   localparam int                 NEXT_PC_WIDTH = 4;

   assign s_cram_arid = 'b0;
   assign s_cram_arlen = 'h0;
   assign s_cram_arsize = 'h2;
   assign s_cram_arburst = 'h1;
   assign s_cram_arlock = 'b0;
   assign s_cram_arcache = 'b0;
   assign s_cram_arprot = 'b0;
   assign s_cram_arqos = 'b0;

   assign s_cram_rready = nrst;
   assign s_cram_arvalid = nrst;

   typedef struct packed {
      logic [CRAM_ADDR_W-1:0] pc;
      logic                   take_flag;
      logic [DATA_W-1:0]      cram_data;
   } lut_t;

   logic [31:0]               s_cram_araddr_n;
   logic [31:0]               s_cram_araddr_d;

   lut_t [1:0] lut = 'b0;
   lut_t [1:0] lut_n;

   always_comb begin
      if (pred_miss) begin
         lut_n <= '0;
      end else if (!ce) begin
         lut_n <= lut;
      end else begin
         if (s_cram_arvalid) begin
            lut_n[$high(lut_n)] <= {s_cram_araddr_d,
                                    take_flag,
                                    s_cram_rdata};
         end else begin
            lut_n[$high(lut_n)] <= 'b0;
         end
         lut_n[$high(lut_n)-1:0] <= lut[$high(lut_n):1];
      end
   end

   wire                                  branch_flag;
   assign branch_flag = (s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BLE ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BLEI ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BLT ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BLTF ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BLTI ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BEQ ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BEQF ||
                         s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_BEQI
                         ) ? 'b1 : 'b0;

   always_comb begin
      if (pred_miss) begin
         s_cram_araddr_n <= pred_miss_dst;
      end else if (!ce) begin
         s_cram_araddr_n <= s_cram_araddr;
      end else if (s_cram_rdata[DATA_W-1:DATA_W-INSTR_W] == I_JMP) begin
         s_cram_araddr_n <= s_cram_rdata[21:0];
      end else if (branch_flag && take_flag) begin
         s_cram_araddr_n <= s_cram_rdata[14:0];
      end else begin
         s_cram_araddr_n <= s_cram_araddr + NEXT_PC_WIDTH;
      end
   end // always_comb

   assign o_current_pc   = lut[0].pc;
   assign o_current_inst = lut[0].cram_data;

   always_comb begin
      if (branch_flag) begin
         if (take_flag) begin
            o_taken_pc   <= lut[0].cram_data[14:0];
            o_untaken_pc <= lut[0].pc + NEXT_PC_WIDTH;
         end else begin
            o_taken_pc   <= lut[0].pc + NEXT_PC_WIDTH;
            o_untaken_pc <= lut[0].cram_data[14:0];
         end
      end else begin
         o_taken_pc   <= '0;
         o_untaken_pc <= '0;
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         lut <= lut_n;
         s_cram_araddr <= s_cram_araddr_n;
         s_cram_araddr_d <= s_cram_araddr;
      end else begin
         lut <= 'b0;
         s_cram_araddr <= 'b0;
         s_cram_araddr_d <= 'b0;
      end
   end

endmodule
