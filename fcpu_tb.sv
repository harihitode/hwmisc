`timescale 1 ns / 1 ps

module fcpu_tb ();

   logic clk = 0;
   initial forever #5 clk <= ~clk;
   logic nrst = 'b0;

   fcpu fcpu_inst
     (
      .*
      );

   initial begin
      #50 nrst <= 'b1;
   end

endmodule
