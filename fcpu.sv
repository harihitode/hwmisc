`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module fcpu
  (
   // clk & reset
   input  clk,
   input  nrst
   );

   logic [2**CRAM_ADDR_W-1:0][DATA_W-1:0] cram = '0;
   wire [CRAM_ADDR_W-1:0]                 cram_addr;
   logic [DATA_W-1:0]                     cram_data = '0;

   always_ff @(posedge clk) begin
      cram_data <= cram[$unsigned(cram_addr)];
   end

   initial begin
      cram[0] <= {I_SETI2, 5'h01, 21'h4};
      cram[1] <= {I_SETI2, 5'h02, 21'h4};
      cram[2] <= {I_SETI2, 5'h03, 21'h777};
      cram[3] <= {I_SETI2, 5'h04, 21'h999};
      cram[4] <= {I_STORER, 5'h03, 5'h02, 5'h01, 11'h0};
      cram[5] <= {I_STORER, 5'h04, 5'h02, 5'h01, 11'h0};
      cram[6] <= {I_LOADR , 5'h05, 5'h02, 5'h01, 11'h0};
   end

   wire [7:0] io_o_data;
   wire       io_o_valid;
   logic      io_o_ready = '0;

   logic [7:0] io_i_data = '0;
   logic       io_i_valid = '0;
   wire        io_i_ready;

   core core_inst
     (
      .*
      );

   // serial

endmodule
