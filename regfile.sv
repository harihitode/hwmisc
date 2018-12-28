`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module register_file
  #(parameter N_RD_PORTS = 3)
  (
   input logic                                        clk,
   input logic                                        pred_miss,
   input logic                                        rsv, // reserve
   input logic [RSV_ID_W-1:0]                         rob_id,
   // from rob to reg
   input logic                                        we,
   input logic [RSV_ID_W-1:0]                         wrQueAddr,
   input logic [REG_ADDR_W-1:0]                       wrAddr,
   input logic [DATA_W-1:0]                           wrData,
   // from reg to core
   input logic [N_RD_PORTS-1:0][REG_ADDR_W-1:0]       rdAddrs,
   output logic [N_RD_PORTS-1:0][DATA_W+RSV_ID_W-1:0] rdData,
   output logic [N_RD_PORTS-1:0]                      rdData_filled,

   input logic                                        clear,
   input logic                                        nrst
   );

   logic [N_RD_PORTS-1:0][REG_ADDR_W-1:0]             args = 'b0;
   logic [N_RD_PORTS-1:0][DATA_W-1:0]                 regs = 'b0;
   logic [2**REG_ADDR_W-1:0][DATA_W-1:0]              reg_file = '0;

   wire [RSV_ID_W-1:0]                                wr_reg_rsv_id;
   wire [REG_ADDR_W-1:0]                              wr_reg_id;
   wire [DATA_W-1:0]                                  wr_reg_data;

   logic [2**REG_ADDR_W-1:0][RSV_ID_W-1:0]            query_n = '0;
   logic [2**REG_ADDR_W-1:0][RSV_ID_W-1:0]            query = '0;
   logic [2**REG_ADDR_W-1:0]                          filled_n = '1;
   logic [2**REG_ADDR_W-1:0]                          filled = '1;

   generate begin for (genvar i = 0; i < N_RD_PORTS; i++) begin
      always_comb begin
         args[i] <= rdAddrs[i];
         regs[i] <= reg_file[$unsigned(args[i])];
         rdData[i] <= {query[$unsigned(args[i])], regs[i]};
         rdData_filled[i] <= filled[$unsigned(args[i])];
      end
   end end
   endgenerate

   assign wr_reg_id = wrAddr;
   assign wr_reg_rsv_id = wrQueAddr;
   assign wr_reg_data = (we) ? wrData : reg_file[$unsigned(wr_reg_id)];

   generate begin
      for (genvar i = 0; i < 2**REG_ADDR_W; i++) begin
         always_comb begin
            query_n[i] <= query[i];
            filled_n[i] <= filled[i];
            // arg[2] is the destination register
            // wr_reg_id is committed ID
            if (rsv && i == $unsigned(args[2])) begin
               query_n[i] <= rob_id;
               filled_n[i] <= 'b0;
            end else if (we && i == $unsigned(wr_reg_id) &&
                         query[i] == $unsigned(wr_reg_rsv_id)) begin
               filled_n[i] <= 'b1;
            end
         end // always_comb
      end
   end endgenerate

   always_ff @(posedge clk) begin
      if (nrst) begin
         reg_file[$unsigned(wr_reg_id)] <= wr_reg_data;
         if (pred_miss) begin
            query <= '0;
            filled <= '1;
         end else begin
            filled <= filled_n;
            query <= query_n;
         end
      end else begin
         reg_file <= '0;
         query <= '0;
         filled <= '1;
      end
   end

endmodule
