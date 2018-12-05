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
   localparam N_UNITS = 2;
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
   logic                         rob_no_wait = 'b0;
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
   logic [2:0]                                      operands_filled;
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
   wire [N_ROB_RD_PORTS-1:0]                        rob_rdData_filled;
   logic [N_ROB_RD_PORTS-1:0][RSV_ID_W-1:0]         rob_rdAddr = 'b0;
   // other TODO
   logic                                            branch_miss = 'b0;

   //
   logic                                            store_commit_valid = 'b0;
   logic [RSV_ID_W-1:0]                             store_commit_id = 'b0;
   logic                                            mmu_reserve = 'b0;
   wire                                             mmu_ready;
   logic [RSV_ID_W+INSTR_W+3*(RSV_ID_W+DATA_W)-1:0] mmu_data = '0;
   logic [2:0]                                      mmu_filled = 'b0;
   wire [CDB_W-1:0]                                 mmu_cdb;
   wire                                             mmu_cdb_ready;

   wire [RSV_ID_W-1:0]                              o_mmu_rsv_id;
   wire                                             o_mmu_valid;
   wire [DATA_W-1:0]                                o_mmu_data;
   wire [DATA_W-1:0]                                o_mmu_addr;
   wire [INSTR_W-1:0]                               o_mmu_opcode;
   logic                                            o_mmu_ready = 'b1;

   assign cdb_valid = |units_cdb_valid;

   always_comb begin
      if (units_cdb_valid[0]) begin
         cdb <= alu_cdb;
      end else if (units_cdb_valid[1]) begin
         cdb <= mmu_cdb;
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
        I_SETI2, I_SAVE : begin
           alu_data <= {rob_id, opcode, operands[2], imm};
           alu_filled <= {operands_filled[2], 1'b1};
        end
        I_SETI1 : begin
           alu_data <= {rob_id, opcode, operands[1], imm};
           alu_filled <= {operands_filled[1], 1'b1};
        end
        I_ADDI, I_SUBI, I_SLI : begin
           alu_data <= {rob_id, opcode, operands[1], operands[0]};
           alu_filled <= {operands_filled[1], operands_filled[0]};
        end
      endcase
   end // always_comb

   always_comb begin
      case (opcode)
        I_STORE, I_STOREB, I_STORER,
        I_STOREF, I_STOREBF, I_STORERF :
          rob_no_wait <= 'b1;
        default:
          rob_no_wait <= 'b0;
      endcase
   end

   always_comb mmu_reservation_data : begin
      case (opcode)
        I_LOAD, I_LOADB,
        I_LOADF, I_LOADBF : begin
           mmu_data <= {rob_id, opcode, {RSV_ID_W+DATA_W{1'b0}}, operands[1], imm};
           mmu_filled <= {1'b1, operands_filled[1], 1'b1};
        end
        I_LOADR, I_LOADRF : begin
           mmu_data <= {rob_id, opcode, {RSV_ID_W+DATA_W{1'b0}}, operands[1], operands[0]};
           mmu_filled <= {1'b1, operands_filled[1], operands_filled[0]};
        end
        I_STORE, I_STOREB,
        I_STOREF, I_STOREBF : begin
           mmu_data <= {rob_id, opcode, operands[2], operands[1], imm};
           mmu_filled <= {operands_filled[2], operands_filled[1], 1'b1};
        end
        I_STORER, I_STORERF : begin
           mmu_data <= {rob_id, opcode, operands[2], operands[1], operands[0]};
           mmu_filled <= {operands_filled[2], operands_filled[1], operands_filled[0]};
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
   end

   always_comb def_mmu_reserve : begin
      case (opcode)
        I_LOAD, I_LOADB, I_LOADR,
        I_LOADF, I_LOADBF, I_LOADRF,
        I_STORE, I_STOREB, I_STORER,
        I_STOREF, I_STOREBF, I_STORERF :
          mmu_reserve <= 'b1;
        default :
          mmu_reserve <= 'b0;
      endcase
   end

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
           I_LOAD, I_LOADB, I_LOADR,
           I_LOADF, I_LOADBF, I_LOADRF,
           I_STORE, I_STOREB, I_STORER,
           I_STOREF, I_STOREBF, I_STORERF :
             halt <= ~mmu_ready;
           default:
             halt <= 'b0;
         endcase
      end
   end

   assign alu_cdb_ready = units_cdb_ready[0];
   assign mmu_cdb_ready = units_cdb_ready[1];

   assign reg_wr_addr = commit_data.dst_reg;
   assign reg_wr_data = commit_data.content;
   always_comb comitter : begin
      if (commit_valid && commit_ready) begin
         reg_we <= 'b0;
         store_commit_valid <= 'b0;
         store_commit_id <= 'b0;
         case (commit_data.opcode)
           I_ADD, I_ADDI,
           I_SUB, I_SUBI,
           I_SL, I_SLI, I_SRL, I_SRA,
           I_SAVE, I_SETI1, I_SETI2,
           I_LOAD, I_LOADB, I_LOADR,
           I_LOADF, I_LOADBF, I_LOADRF : begin
              reg_we <= 'b1;
           end
           I_STORE, I_STOREB, I_STORER,
           I_STOREF, I_STOREBF, I_STORERF : begin
              store_commit_valid <= 'b1;
              store_commit_id <= commit_data.station_id;
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

   memory_management_unit mmu_inst
     (
      .clk(clk),

      .i_valid(mmu_reserve),
      .i_data(mmu_data),
      .i_filled(mmu_filled),
      .i_ready(mmu_ready),

      .store_commit_valid(store_commit_valid),
      .store_commit_id(store_commit_id),

      .cdb(cdb),
      .cdb_valid(cdb_valid),

      .o_cdb(mmu_cdb),
      .o_cdb_valid(units_cdb_valid[1]),
      .o_cdb_ready(mmu_cdb_ready),

      .o_valid(o_mmu_valid),
      .o_rsv_id(o_mmu_rsv_id),
      .o_opcode(o_mmu_opcode),
      .o_address(o_mmu_addr),
      .o_data(o_mmu_data),
      .o_ready(o_mmu_ready),

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
      .i_no_wait(rob_no_wait),
      .i_opcode(opcode),
      .i_dst_reg(o_current_inst[25:21]),

      .rob_id(rob_rdAddr),
      .rob_data(rob_rdData),
      .rob_data_filled(rob_rdData_filled),

      .o_valid(commit_valid),
      .o_commit_data(commit_data),
      .o_ready(commit_ready),
      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst)
      );

endmodule
