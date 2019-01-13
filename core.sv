`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module core
  (
   input logic                 clk,

   // code ram {
   // Slave Interface Read Address Ports
   output logic [3:0]          s_cram_arid,
   output logic [31:0]         s_cram_araddr,
   output logic [7:0]          s_cram_arlen,
   output logic [2:0]          s_cram_arsize,
   output logic [1:0]          s_cram_arburst,
   output logic [0:0]          s_cram_arlock,
   output logic [3:0]          s_cram_arcache,
   output logic [2:0]          s_cram_arprot,
   output logic [3:0]          s_cram_arqos,
   output logic                s_cram_arvalid,
   input logic                 s_cram_arready,

   // Slave Interface Read Data Ports
   output logic                s_cram_rready,
   input logic [3:0]           s_cram_rid,
   input logic [31:0]          s_cram_rdata,
   input logic [1:0]           s_cram_rresp,
   input logic                 s_cram_rlast,
   input logic                 s_cram_rvalid,
   // }
   // to MMU {
   output logic [RSV_ID_W-1:0] mmu_rsv_id,
   output logic                mmu_valid,
   output logic [DATA_W-1:0]   mmu_data,
   output logic [DATA_W-1:0]   mmu_addr,
   output logic [INSTR_W-1:0]  mmu_opcode,
   input logic                 mmu_ready,

   input logic [CDB_W-1:0]     mmu_cdb,
   input logic                 mmu_cdb_valid,
   output logic                mmu_cdb_ready,
   // }
   input                       nrst
   );

   wire                        take_flag;
   wire                        pred_miss;
   wire                        pred_condition;
   wire                        true_condition;

   wire [CRAM_ADDR_W-1:0]      o_current_pc;
   wire                        o_current_valid;
   wire [DATA_W-1:0]           o_current_inst;
   wire                        o_current_taken;
   wire [CRAM_ADDR_W-1:0]      o_true_pc;

   wire [INSTR_W-1:0]          opcode;
   wire [CRAM_ADDR_W-1:0]      program_counter;
   logic [CRAM_ADDR_W-1:0]     committed_program_counter = 'b0;
   logic                       halt = 'b0;

   // common data bus
   localparam N_UNITS = 4;
   localparam N_REG_RD_PORTS = 3;
   localparam N_ROB_RD_PORTS = 6;
   logic [CDB_W-1:0]           cdb = 'b0;
   logic                       cdb_exception = 'b0;
   wire                        cdb_valid;
   wire [N_UNITS-1:0][CDB_W-1:0] units_cdb;
   wire [N_UNITS-1:0]            units_cdb_valid;
   logic [N_UNITS-1:0]           units_cdb_exception = 'b0;
   logic [N_UNITS-1:0]           units_cdb_ready = '0;

   // ROB
   wire [RSV_ID_W-1:0]           rob_id;
   wire                          rob_ready;
   logic                         rob_reserve = 'b0;
   logic                         rob_no_wait = 'b0;
   wire                          commit_valid;
   logic                         commit_ready = 'b1;
   wire                          station_t commit_data;

   // ALU
   logic [RSV_ID_W+INSTR_W+2*(RSV_ID_W+DATA_W)-1:0] alu_data = '0;
   logic [1:0]                                      alu_filled = 'b0;
   logic                                            alu_reserve = 'b0;
   wire                                             alu_ready;

   logic [2:0][RSV_ID_W+DATA_W-1:0]                 operands;
   logic [2:0]                                      operands_filled;
   logic [RSV_ID_W+DATA_W-1:0]                      imm;

   // BRU
   logic [RSV_ID_W+INSTR_W+3*(RSV_ID_W+DATA_W)-1:0] bru_data = '0;
   logic [2:0]                                      bru_filled = 'b0;
   logic                                            bru_reserve = 'b0;
   logic                                            bru_condition = 'b0;
   wire                                             bru_ready;

   // REGs
   logic                                            reg_reserve = 'b0;
   wire [N_REG_RD_PORTS-1:0]                        reg_filled;
   wire [N_REG_RD_PORTS-1:0][REG_ADDR_W-1:0]        reg_rdAddrs;
   wire [N_REG_RD_PORTS-1:0][RSV_ID_W+DATA_W-1:0]   reg_rdData;

   // from rob to reg
   logic                                            reg_we = 'b0;
   wire [REG_ADDR_W-1:0]                            reg_wr_addr;
   wire [RSV_ID_W-1:0]                              reg_wr_rsv_addr;
   wire [DATA_W-1:0]                                reg_wr_data;
   wire [N_ROB_RD_PORTS-1:0][RSV_ID_W+DATA_W-1:0]   rob_rdData;
   wire [N_ROB_RD_PORTS-1:0]                        rob_rdData_filled;
   logic [N_ROB_RD_PORTS-1:0][RSV_ID_W-1:0]         rob_rdAddr = 'b0;

   //
   logic                                            store_commit_valid = 'b0;
   logic                                            store_commit_invalidate = 'b0;
   logic [RSV_ID_W-1:0]                             store_commit_id = 'b0;
   logic                                            mfu_reserve = 'b0;
   wire                                             mfu_ready;
   logic [RSV_ID_W+INSTR_W+3*(RSV_ID_W+DATA_W)-1:0] mfu_data = '0;
   logic [2:0]                                      mfu_filled = 'b0;

   wire [RSV_ID_W-1:0]                              o_mfu_rsv_id;
   wire                                             o_mfu_valid;
   wire [DATA_W-1:0]                                o_mfu_data;
   wire [DATA_W-1:0]                                o_mfu_addr;
   wire [INSTR_W-1:0]                               o_mfu_opcode;
   wire                                             o_mfu_ready;

   logic [CRAM_ADDR_W-1:0]                          sch_address = 'b0;
   logic                                            sch_address_valid = 'b0;

   assign cdb_valid = |units_cdb_valid;
   assign o_mfu_ready = mmu_ready;

   always_comb begin
      for (int i = 0; i < N_UNITS; i++) begin
         if (units_cdb_valid[i]) begin
            cdb <= units_cdb[i];
            cdb_exception <= units_cdb_exception[i];
            break;
         end
      end
   end

   assign opcode = o_current_inst[INSTR_POS+:INSTR_W];
   assign program_counter = o_current_pc;
   assign reg_rdAddrs = o_current_inst[11+:3*REG_ADDR_W];

   always_comb def_arguments : begin
      if (opcode == I_SAVE) begin
         imm <= (RSV_ID_W+DATA_W)'(program_counter);
      end else begin
         imm <= (RSV_ID_W+DATA_W)'(o_current_inst[15:0]);
      end
   end

   generate begin for (genvar i = 0; i < 3; i++) begin
      always_comb begin
         if (reg_filled[i]) begin
            operands[i] <= reg_rdData[i];
            operands_filled[i] <= reg_filled[i];
         end else if (cdb_valid && reg_rdData[i][DATA_W+:RSV_ID_W] == cdb[DATA_W+:RSV_ID_W]) begin
            operands[i] <= cdb;
            operands_filled[i] <= 'b1;
         end else begin
            operands[i] <= rob_rdData[i];
            operands_filled[i] <= rob_rdData_filled[i];
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
        I_SETI1, I_SETI2 : begin
           alu_data <= {rob_id, opcode, operands[2], imm};
           alu_filled <= {operands_filled[2], 1'b1};
        end
        I_ADDI, I_SUBI : begin
           alu_data <= {rob_id, opcode, operands[1], imm};
           alu_filled <= {operands_filled[1], 1'b1};
        end
        I_SAVE : begin
           alu_data <= {rob_id, opcode, (DATA_W+RSV_ID_W)'($unsigned(o_current_pc)), imm};
           alu_filled <= {1'b1, 1'b1};
        end
        I_ADD, I_SUB, I_AND, I_OR, I_XOR : begin
           alu_data <= {rob_id, opcode, operands[1], operands[0]};
           alu_filled <= {operands_filled[1], operands_filled[0]};
        end
      endcase
   end

   always_comb bru_reservation_data : begin
      bru_condition <= o_current_taken;
      case (opcode)
        I_BLT, I_BEQ : begin
           bru_data <= {rob_id, opcode, operands[2], operands[1],
                        (DATA_W+RSV_ID_W)'($unsigned(o_true_pc))};
           bru_filled <= {operands_filled[2], operands_filled[1], 1'b1};
        end
        I_JMP : begin
           bru_data <= {rob_id, opcode, imm, imm,
                        (DATA_W+RSV_ID_W)'($unsigned(o_true_pc))};
           bru_filled <= {1'b1, 1'b1, 1'b1};
        end
        I_JMPR : begin
           bru_data <= {rob_id, opcode, imm, imm,
                        operands[2]};
           bru_filled <= {1'b1, 1'b1, operands_filled[2]};
        end
      endcase
   end

   always_comb begin
      case (opcode)
        I_STORE, I_STOREB, I_STORER,
//        I_STOREF, I_STOREBF, I_STORERF,
        I_OUTPUT :
          rob_no_wait <= 'b1;
        default :
          rob_no_wait <= 'b0;
      endcase
   end

   always_comb mfu_reservation_data : begin
      case (opcode)
        I_LOAD, I_LOADB : begin
//        I_LOADF, I_LOADBF : begin
           mfu_data <= {rob_id, opcode, {RSV_ID_W+DATA_W{1'b0}}, operands[1], imm};
           mfu_filled <= {1'b1, operands_filled[1], 1'b1};
        end
        I_LOADR : begin
           mfu_data <= {rob_id, opcode, {RSV_ID_W+DATA_W{1'b0}}, operands[1], operands[0]};
           mfu_filled <= {1'b1, operands_filled[1], operands_filled[0]};
        end
        I_INPUT : begin
           mfu_data <= {rob_id, opcode, {RSV_ID_W+DATA_W{1'b0}}, {RSV_ID_W+DATA_W{1'b1}}, {RSV_ID_W+DATA_W{1'b0}}};
           mfu_filled <= {1'b1, 1'b1, 1'b1};
        end
        I_STORE, I_STOREB : begin
//        I_STOREF, I_STOREBF : begin
           mfu_data <= {rob_id, opcode, operands[2], operands[1], imm};
           mfu_filled <= {operands_filled[2], operands_filled[1], 1'b1};
        end
        I_STORER : begin
           mfu_data <= {rob_id, opcode, operands[2], operands[1], operands[0]};
           mfu_filled <= {operands_filled[2], operands_filled[1], operands_filled[0]};
        end
        I_OUTPUT : begin
           mfu_data <= {rob_id, opcode, operands[2], {RSV_ID_W+DATA_W{1'b1}}, {RSV_ID_W+DATA_W{1'b0}}};
           mfu_filled <= {operands_filled[2], 1'b1, 1'b1};
        end
      endcase
   end

   always_comb def_rob_reserve : begin
      if (o_current_inst != 'b0) begin
         rob_reserve <= (~halt & o_current_valid);
      end else begin
         rob_reserve <= 'b0;
      end
   end

   always_comb def_alu_reserve : begin
      case (opcode)
        I_ADD, I_ADDI,
        I_SUB, I_SUBI,
        I_SL, I_SRL, I_SRA,
        I_AND, I_OR, I_XOR,
        I_SAVE, I_SETI1, I_SETI2 :
          alu_reserve <= ~halt & o_current_valid;
        default :
          alu_reserve <= 'b0;
      endcase
   end

   always_comb def_bru_reserve : begin
      case (opcode)
        I_BLT, I_BEQ, I_JMP, I_JMPR :
          bru_reserve <= ~halt & o_current_valid;
        default :
          bru_reserve <= 'b0;
      endcase
   end

   always_comb def_mfu_reserve : begin
      case (opcode)
        I_LOAD, I_LOADB, I_LOADR,
//        I_LOADF, I_LOADBF, I_LOADRF,
        I_STORE, I_STOREB, I_STORER,
//        I_STOREF, I_STOREBF, I_STORERF,
        I_INPUT, I_OUTPUT :
          mfu_reserve <= ~halt & o_current_valid;
        default :
          mfu_reserve <= 'b0;
      endcase
   end

   always_comb def_reg_reserve : begin
      case (opcode)
        I_LOAD, I_LOADB, I_LOADR,
        I_ADD, I_ADDI, I_SUB, I_SUBI,
        I_SL, I_SRL, I_SRA,
        I_AND, I_OR, I_XOR,
        I_SAVE, I_SETI1, I_SETI2, I_INPUT :
          reg_reserve <= ~halt & o_current_valid;
        default :
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
      if (!rob_ready || pred_miss) begin
         halt <= 'b1;
      end else begin
         case (opcode)
           I_ADD, I_ADDI,
           I_SUB, I_SUBI,
           I_SL, I_SRL, I_SRA,
           I_AND, I_OR, I_XOR,
           I_SAVE, I_SETI1, I_SETI2 :
             halt <= ~alu_ready;
           I_LOAD, I_LOADB, I_LOADR,
//           I_LOADF, I_LOADBF, I_LOADRF,
           I_STORE, I_STOREB, I_STORER,
//           I_STOREF, I_STOREBF, I_STORERF,
           I_INPUT, I_OUTPUT :
             halt <= ~mfu_ready;
           I_BLT, I_BEQ, I_JMP, I_JMPR :
             halt <= ~bru_ready;
           default :
             halt <= 'b0;
         endcase
      end
   end

   assign reg_wr_rsv_addr = commit_data.station_id;
   assign reg_wr_addr = commit_data.dst_reg;
   assign reg_wr_data = commit_data.content;

   always_comb begin
      store_commit_id <= commit_data.station_id;
      store_commit_invalidate <= commit_data.invalidate;
   end

   always_comb begin
      sch_address_valid <= 'b0;
      sch_address <= 'b0;
      if (pred_miss) begin
         sch_address_valid <= 'b1;
         if (commit_data.opcode == I_JMP ||
             commit_data.opcode == I_JMPR) begin
            sch_address <= commit_data.content;
         end else if (true_condition) begin
            sch_address <= committed_program_counter + (CRAM_ADDR_W)'(commit_data.content);
         end else begin
            sch_address <= committed_program_counter + 'h4;
         end
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         if (commit_valid && commit_ready && ~commit_data.invalidate) begin
            if (commit_data.opcode == I_JMP ||
                commit_data.opcode == I_JMPR) begin
               committed_program_counter <= commit_data.content;
            end else if (pred_miss) begin
               committed_program_counter <= sch_address;
            end else begin
               committed_program_counter <= committed_program_counter + 'h4;
            end
         end
      end else begin
         committed_program_counter <= 'b0; // TODO
      end
   end

   always_comb comitter : begin
      if (commit_valid && commit_ready) begin
         reg_we <= 'b0;
         store_commit_valid <= 'b0;
         case (commit_data.opcode)
           I_ADD, I_ADDI,
           I_SUB, I_SUBI,
           I_SL, I_SRL, I_SRA,
           I_AND, I_OR, I_XOR,
           I_SAVE, I_SETI1, I_SETI2,
           I_LOAD, I_LOADB, I_LOADR,
//           I_LOADF, I_LOADBF, I_LOADRF,
           I_INPUT : begin
              reg_we <= 'b1;
           end
           I_STORE, I_STOREB, I_STORER,
//           I_STOREF, I_STOREBF, I_STORERF,
           I_OUTPUT : begin
              store_commit_valid <= 'b1;
           end
         endcase
      end else begin
         reg_we <= 'b0;
         store_commit_valid <= 'b0;
      end
   end // always_comb

   scheduler scheduler_inst
     (
      .*,
      .ce(~halt),
      .address(sch_address),
      .address_valid(sch_address_valid)
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

      .o_cdb(units_cdb[2]),
      .o_valid(units_cdb_valid[2]),
      .o_ready(units_cdb_ready[2]),

      .nrst(nrst)
      );

   branch_unit branch_unit_inst
     (
      .clk(clk),
      .i_valid(bru_reserve),
      .i_data(bru_data),
      .i_filled(bru_filled),
      .i_condition(bru_condition),
      .i_ready(bru_ready),

      .cdb(cdb),
      .cdb_valid(cdb_valid),

      .take_flag(take_flag),
      .commit_valid(commit_valid),
      .commit_data(commit_data),
      .commit_id(commit_data.station_id),
      .commit_opcode(commit_data.opcode),

      .o_cdb(units_cdb[3]),
      .o_valid(units_cdb_valid[3]),
      .o_ready(units_cdb_ready[3]),

      .pred_miss(pred_miss),
      .pred_condition(pred_condition),
      .true_condition(true_condition),

      .nrst(nrst)
      );

   memory_functional_unit mfu_inst
     (
      .clk(clk),

      .i_valid(mfu_reserve),
      .i_data(mfu_data),
      .i_filled(mfu_filled),
      .i_ready(mfu_ready),

      .store_commit_valid(store_commit_valid),
      .store_commit_invalidate(store_commit_invalidate),
      .store_commit_id(store_commit_id),

      .cdb(cdb),
      .cdb_valid(cdb_valid),

      .o_cdb(units_cdb[1]),
      .o_cdb_valid(units_cdb_valid[1]),
      .o_cdb_ready(units_cdb_ready[1]),

      .o_valid(o_mfu_valid),
      .o_rsv_id(o_mfu_rsv_id),
      .o_opcode(o_mfu_opcode),
      .o_address(o_mfu_addr),
      .o_data(o_mfu_data),
      .o_ready(o_mfu_ready),

      .nrst(nrst)
      );

   register_file
     #(.N_RD_PORTS(N_REG_RD_PORTS))
   reg_inst
     (
      .clk(clk),
      .pred_miss(pred_miss),
      .rsv(reg_reserve),
      .rob_id(rob_id),

      .we(reg_we),
      .wrAddr(reg_wr_addr),
      .wrQueAddr(reg_wr_rsv_addr),
      .wrData(reg_wr_data),

      .rdAddrs(reg_rdAddrs),
      .rdData(reg_rdData),
      .rdData_filled(reg_filled),

      .clear(pred_miss),
      .nrst(nrst)
      );

   reorder_buffer rob_inst
     (
      .clk(clk),
      .i_valid(rob_reserve),
      .i_ready(rob_ready), // rob nfull
      .i_rsv_id(rob_id),
      .i_no_wait(rob_no_wait),
      .i_opcode(opcode),
      .i_dst_reg(o_current_inst[25:21]),

      .rob_id(rob_rdAddr),
      .rob_data(rob_rdData),
      .rob_data_filled(rob_rdData_filled),

      .o_valid(commit_valid),
      .o_commit_data(commit_data),
      .o_ready(commit_ready),

      .cdb_exception(cdb_exception),
      .cdb_valid(cdb_valid),
      .cdb(cdb),

      .clear(pred_miss),
      .nrst(nrst)
      );

   assign mmu_rsv_id = o_mfu_rsv_id;
   assign mmu_valid = o_mfu_valid;
   assign mmu_data = o_mfu_data;
   assign mmu_addr = o_mfu_addr;
   assign mmu_opcode = o_mfu_opcode;
   assign units_cdb[0] = mmu_cdb;
   assign units_cdb_valid[0] = mmu_cdb_valid;
   assign mmu_cdb_ready = units_cdb_ready[0];

endmodule
