`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module register_file
  #(parameter N_RD_PORTS = 3)
  (
   input logic                                        clk,
   input logic                                        branch_miss,
   input logic                                        rsv, // reserve
   input logic [RSV_ID_W-1:0]                         rob_id,
   // from rob to reg
   input logic                                        we,
   input logic [DATA_W+RSV_ID_W-1:0]                  wrData,
   // from reg to core
   input logic [N_RD_PORTS-1:0][REG_ADDR_W-1:0]       rdAddrs,
   output logic [N_RD_PORTS-1:0][DATA_W+RSV_ID_W-1:0] rdData,
   output logic [N_RD_PORTS-1:0]                      rdData_filled,

   input logic                                        nrst
   );

   wire [N_RD_PORTS-1:0][REG_ADDR_W-1:0]        args;
   wire [N_RD_PORTS-1:0][DATA_W-1:0]            regs;
   logic [2**REG_ADDR_W-1:0][DATA_W-1:0]        reg_file = '0;

   wire [RSV_ID_W-1:0]                          wr_reg_id;
   wire [DATA_W-1:0]                            wr_reg_data;

   logic [2**REG_ADDR_W-1:0][RSV_ID_W-1:0]      query_n = '0;
   logic [2**REG_ADDR_W-1:0][RSV_ID_W-1:0]      query = '0;
   logic [2**REG_ADDR_W-1:0]                    filled_n = '1;
   logic [2**REG_ADDR_W-1:0]                    filled = '1;

   wire [N_RD_PORTS-1:0][RSV_ID_W-1:0]          regQs;

   generate begin for (genvar i = 0; i < N_RD_PORTS; i++) begin
      assign args[i] = rdAddrs[i];
      assign regs[i] = reg_file[$unsigned(args[i])];
      assign regQs[i] = query[$unsigned(args[i])];
      assign rdData[i] = {regQs[i], regs[i]};
      assign rdData_filled[i] = filled[$unsigned(args[i])];
   end end
   endgenerate

   assign wr_reg_id = wrData[DATA_W+RSV_ID_W-1:DATA_W];
   assign wr_reg_data = (we) ? wrData[DATA_W-1:0] : reg_file[$unsigned(wr_reg_id)];

   always_comb begin
      // arg[0] is the destination register
      automatic int dst_id = $unsigned(args[0]);
      // the id which is committed
      automatic int cmt_id = $unsigned(wr_reg_id);
      for (int i = 0; i < 2**REG_ADDR_W; i++) begin
         if (rsv && i == dst_id) begin
            query_n[i] <= rob_id;
            filled_n[i] <= '0;
         end else if (we && i == cmt_id) begin
            query_n[i] <= '0;
            filled_n[i] <= '1;
         end else begin
            query_n[i] <= query[i];
            filled_n[i] <= filled[i];
         end
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         reg_file[$unsigned(wr_reg_id)] <= wr_reg_data;
         if (branch_miss) begin
            query <= '0;
         end else begin
            query <= query_n;
         end
         filled <= filled_n;
      end else begin
         reg_file <= '0;
         query <= '0;
         filled <= '1;
      end
   end

endmodule
