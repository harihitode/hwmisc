`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module core
  (
   input logic                    clk,

   // code ram {
   output logic [CRAM_ADDR_W-1:0] cram_addr,
   input logic [DATA_W-1:0]       cram_data,
   // }
   // I/O {
   output logic [7:0]             io_o_data,
   output logic                   io_o_valid,
   input logic                    io_o_ready,

   input logic [7:0]              io_i_data,
   input logic                    io_i_valid,
   output logic                   io_i_ready,
   // }
   input                          nrst
   );

   logic                          take_flag = '0;
   logic                          pred_miss = '0;
   logic [CRAM_ADDR_W-1:0]        pred_miss_dst = '0;

   wire [CRAM_ADDR_W-1:0]         o_current_pc;
   wire [DATA_W-1:0]              o_current_inst;
   wire [CRAM_ADDR_W-1:0]         o_taken_pc;
   wire [CRAM_ADDR_W-1:0]         o_untaken_pc;

   wire [INSTR_W-1:0]             opcode;
   wire [CRAM_ADDR_W-1:0]         program_counter;
   logic                          halt = 'b0;

   // common data bus
   localparam N_UNITS = 1;
   localparam N_REG_RD_PORTS = 3;
   localparam N_ROB_RD_PORTS = 6;
   logic [CDB_W-1:0]              cdb = 'b0;
   wire                           cdb_valid;
   wire [N_UNITS-1:0]             units_cdb_valid;
   logic [N_UNITS-1:0]            units_cdb_ready = '0;

   // ROB
   wire [RSV_ID_W-1:0]           rob_id;
   wire                          rob_ready;
   wire                          rob_reserve;
   wire                          commit_valid;
   logic                         commit_ready = 'b1;
   wire                          station_t commit_data;

   // ALU
   logic [RSV_ID_W+INSTR_W+2*(RSV_ID_W+DATA_W)-1:0] alu_data = '0;
   logic [1:0]                                      alu_filled = 'b0;
   logic                                            alu_reserve = 'b0;
   wire                                             alu_ready;
   wire [CDB_W-1:0]                                 alu_cdb;
   wire                                             alu_cdb_ready;

   logic [2:0][RSV_ID_W+DATA_W-1:0]                 operands;
   logic [RSV_ID_W+DATA_W-1:0]                      imm;

   // REGs
   logic                                            reg_reserve = 'b0;
   wire [N_REG_RD_PORTS-1:0]                        reg_filled;
   wire [N_REG_RD_PORTS-1:0][REG_ADDR_W-1:0]        reg_rdAddrs;
   wire [N_REG_RD_PORTS-1:0][RSV_ID_W+DATA_W-1:0]   reg_rdData;

   // from rob to reg
   logic                                            reg_we = 'b0;
   wire [REG_ADDR_W-1:0]                            reg_wr_addr;
   wire [DATA_W-1:0]                                reg_wr_data;
   wire [N_ROB_RD_PORTS-1:0][RSV_ID_W+DATA_W-1:0]   rob_rdData;
   logic [N_ROB_RD_PORTS-1:0][RSV_ID_W-1:0]         rob_rdAddr = 'b0;
   // other TODO
   logic                                            branch_miss = 'b0;

   assign cdb_valid = |units_cdb_valid;

   always_comb begin
      if (units_cdb_valid[0]) begin
         cdb <= alu_cdb;
      end else begin
         cdb <= 'b0;
      end
   end

   assign opcode = o_current_inst[INSTR_POS+:INSTR_W];
   assign program_counter = o_current_pc;
   assign reg_rdAddrs = o_current_inst[11+:3*REG_ADDR_W];

   assign rob_reserve = (o_current_inst != 'b0) ? ~halt : 'b0;

   always_comb def_arguments : begin
      if (opcode == I_SAVE) begin
         imm <= (RSV_ID_W+DATA_W)'(program_counter);
      end else begin
         imm <= (RSV_ID_W+DATA_W)'(o_current_inst[15:0]);
      end
   end

   generate begin for (genvar i = 0; i < 3; i++) begin
      always_comb begin
         if (reg_filled[0]) begin
            operands[i] <= reg_rdData[i];
         end else if (reg_rdData[i][DATA_W+:RSV_ID_W] == cdb[DATA_W+:RSV_ID_W]) begin
            operands[i] <= cdb;
         end else begin
            operands[i] <= rob_rdData[i];
         end
      end
   end end
   endgenerate

   generate begin for (genvar i = 0; i < 3; i++) begin
      always_comb begin
         rob_rdAddr[i] <= reg_rdData[i][DATA_W+:RSV_ID_W];
         rob_rdAddr[i+3] <= '0;
      end
   end end
   endgenerate

   always_comb alu_reservation_data : begin
      case (opcode)
        I_SETI2, I_SAVE : begin
           alu_data <= {rob_id, opcode, operands[0], imm};
           alu_filled <= {reg_filled[2], 1'b1};
        end
        I_SETI1 : begin
           alu_data <= {rob_id, opcode, operands[1], imm};
           alu_filled <= {reg_filled[1], 1'b1};
        end
        I_ADDI, I_SUBI, I_SLI : begin
           alu_data <= {rob_id, opcode, operands[1], operands[2]};
           alu_filled <= {reg_filled[1], reg_filled[0]};
        end
      endcase
   end

   always_comb def_alu_reserve : begin
      case (opcode)
        I_ADD, I_ADDI,
        I_SUB, I_SUBI,
        I_SL, I_SLI, I_SRL, I_SRA,
        I_SAVE, I_SETI1, I_SETI2 :
          alu_reserve <= ~halt;
        default :
          alu_reserve <= 'b0;
      endcase
   end // always_comb

   always_comb def_reg_reserve : begin
      case (opcode)
        I_LOAD, I_LOADB, I_LOADR,
        I_ADD, I_ADDI, I_SUB, I_SUBI,
        I_SL, I_SLI, I_SRL, I_SRA,
        I_SAVE, I_SETI1, I_SETI2, I_F2I :
          reg_reserve <= 'b1;
        default:
          reg_reserve <= 'b0;
      endcase
   end

   always_comb cdb_requests_check : begin
      units_cdb_ready <= 'b0;
      for (int i = 0; i < N_UNITS; i++) begin
         if (units_cdb_valid[i]) begin
            units_cdb_ready[i] <= 'b1;
            break;
         end
      end
   end

   always_comb halt_check : begin
      if (!rob_ready || branch_miss) begin
         halt <= 'b1;
      end else begin
         case (opcode)
           I_ADD, I_ADDI,
           I_SUB, I_SUBI,
           I_SL, I_SLI, I_SRL, I_SRA,
           I_SAVE, I_SETI1, I_SETI2 :
             halt <= ~alu_ready;
           default:
             halt <= 'b0;
         endcase
      end
   end

   assign alu_cdb_ready = units_cdb_ready[0];

   assign reg_wr_addr = commit_data.dst_reg;
   assign reg_wr_data = commit_data.content;
   always_comb comitter : begin
      if (commit_valid && commit_ready) begin
         case (commit_data.opcode)
           I_ADD, I_ADDI,
           I_SUB, I_SUBI,
           I_SL, I_SLI, I_SRL, I_SRA,
           I_SAVE, I_SETI1, I_SETI2 : begin
              reg_we <= 'b1;
           end
           default: begin
              reg_we <= 'b0;
           end
         endcase
      end else begin
         reg_we <= 'b0;
      end
   end

   scheduler scheduler_inst
     (
      .*,
      .ce(~halt)
      );

   alu alu_inst
     (
      .clk(clk),
      .i_valid(alu_reserve),
      .i_data(alu_data),
      .i_filled(alu_filled),
      .i_ready(alu_ready),

      .cdb(cdb),
      .cdb_valid(cdb_valid),

      .o_cdb(alu_cdb),
      .o_valid(units_cdb_valid[0]),
      .o_ready(alu_cdb_ready),

      .nrst(nrst)
      );

   register_file
     #(.N_RD_PORTS(N_REG_RD_PORTS))
   reg_inst
     (
      .clk(clk),
      .branch_miss(branch_miss),
      .rsv(reg_reserve),
      .rob_id(rob_id),

      .we(reg_we),
      .wrAddr(reg_wr_addr),
      .wrData(reg_wr_data),

      .rdAddrs(reg_rdAddrs),
      .rdData(reg_rdData),
      .rdData_filled(reg_filled),

      .nrst(nrst)
      );

   reorder_buffer rob_inst
     (
      .clk(clk),
      .i_valid(rob_reserve),
      .i_ready(rob_ready), // rob nfull
      .i_rsv_id(rob_id),
      .i_opcode(opcode),
      .i_dst_reg(o_current_inst[25:21]),

      .rob_id(rob_rdAddr),
      .rob_data(rob_rdData),

      .o_valid(commit_valid),
      .o_commit_data(commit_data),
      .o_ready(commit_ready),
      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst)
      );

endmodule
