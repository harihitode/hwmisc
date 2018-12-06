`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module memory_management_unit
  (
   input logic               clk,
   // core to mmu {
   input logic               rsv_id,
   input logic               valid,
   input logic [DATA_W-1:0]  data,
   input logic [DATA_W-1:0]  address,
   input logic [INSTR_W-1:0] opcode,
   output logic              ready,
   // }
   // GMEM {

   // }
   // I/O {
   output logic [7:0]        io_o_data,
   output logic              io_o_valid,
   input logic               io_o_ready,

   input logic [7:0]         io_i_data,
   input logic               io_i_valid,
   output logic              io_i_ready,
   // }

   input logic [CDB_W-1:0]   cdb,
   input logic               cdb_valid,

   output logic [CDB_W-1:0]  o_cdb,
   output logic              o_cdb_valid,
   input logic               o_cdb_ready,

   input logic               nrst
   );

   logic                     op_is_store = '0;

   always_comb begin
      case (opcode)
        I_STORE, I_STOREB, I_STORER,
        I_STOREF, I_STOREBF, I_STORERF,
        I_OUTPUT : begin
           op_is_store <= 'b1;
        end
        default : begin
           op_is_store <= 'b0;
        end
      endcase
   end

   always_comb begin
      if (valid && op_is_store && address == '1) begin
         ready <= io_o_ready;
      end else if (valid && !op_is_store && address == '1) begin
         ready <= io_i_valid;
      end else begin
         ready <= 'b0;
      end
   end

   always_comb begin
      if (valid && ready && op_is_store && address == '1) begin
         io_o_valid <= 'b1;
         io_o_data <= data;
      end else begin
         io_o_valid <= 'b0;
         io_o_data <= 'b0;
      end
   end

   always_comb begin
      if (valid && !op_is_store && address == '1) begin
         o_cdb_valid <= io_i_valid;
         io_i_ready <= o_cdb_ready;
         o_cdb <= {rsv_id, io_i_data};
      end else begin
         o_cdb_valid <= 'b0;
         io_i_ready <= 'b0;
         o_cdb <= 'b0;
      end
   end

endmodule
