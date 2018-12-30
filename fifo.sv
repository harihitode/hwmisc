// FIFO

`timescale 1 ns / 1 ps

module fifo
  #(parameter FIFO_DEPTH_W = 5,
    parameter DATA_W = 8)
   (
    input                   clk,
    input                   nrst,
    input [DATA_W-1:0]      a_data, // in port
    input                   a_valid,
    output reg              a_ready,
    output reg [DATA_W-1:0] b_data,
    output reg              b_valid,
    input                   b_ready
    );

   localparam logic [1:0]   FIFO_DEFAULT = 2'b00;
   localparam logic [1:0]   FIFO_R = 2'b01;
   localparam logic [1:0]   FIFO_W = 2'b10;
   localparam logic [1:0]   FIFO_WR = 2'b11;

   logic [0:(2**FIFO_DEPTH_W)-1][DATA_W-1:0] mem = '0;
   logic [((FIFO_DEPTH_W > 0) ? FIFO_DEPTH_W : 1)-1:0] read_pos = 'd0, write_pos = 'd0;
   logic                                     full = 0;
   logic [1:0]                               instruction;

   assign a_ready = ~full;
   assign b_valid = (write_pos == read_pos) ? full : 1'b1;
   assign b_data = mem[read_pos];
   assign instruction = {a_valid & a_ready, b_valid & b_ready};

   localparam int                            NEXT_POS = (FIFO_DEPTH_W > 0) ? 1 : 0;

   always_ff @(posedge clk) begin
      if (nrst) begin
         if (instruction & FIFO_R) read_pos <= read_pos + NEXT_POS;
         if (instruction & FIFO_W) write_pos <= write_pos + NEXT_POS;
         if (instruction & FIFO_W) mem[write_pos] <= a_data + NEXT_POS;
      end else begin
         read_pos <= 'd0;
         write_pos <= 'd0;
      end
   end

   // about full flag
   always_ff @(posedge clk) begin
      if (nrst) begin
         unique case (instruction)
           FIFO_R: begin // only read === release full flag
              full <= 0;
           end
           FIFO_W: begin
              if ($unsigned(read_pos) ==
                  $unsigned(((FIFO_DEPTH_W > 0) ? FIFO_DEPTH_W : 1)'(write_pos + NEXT_POS)))
                full <= 1;
           end
           default: begin
              full <= full;
           end
         endcase // unique case (instruction)
      end else begin // if (nrst)
         full <= 0;
      end
   end

endmodule
