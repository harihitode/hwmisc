`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module cache
  (
   // part a (from computing-unit)
   input logic [CACHE_N_BANKS*DATA_W/8-1:0] wea,
   input logic                              ena,
   input logic unsigned [(M+L)-1:0]         addra,
   input logic [CACHE_N_BANKS*DATA_W-1:0]   dia,
   output logic [CACHE_N_BANKS*DATA_W-1:0]  doa,

   // port b (from axi-controller)
   input logic                              enb,
   input logic [(M+L)-1:0]                  wr_fifo_rqst_addr,
   input logic [(M+L)-1:0]                  rd_fifo_rqst_addr,
   input logic [CACHE_N_BANKS*DATA_W-1:0]   wr_fifo_dout,
   output logic                             rd_fifo_din_v = 'b0,
   output logic [CACHE_N_BANKS*DATA_W-1:0]  dob,

   // ticket signals
   input logic                              ticket_rqst_wr,
   output logic                             ticket_ack_wr_fifo,
   input logic                              ticket_rqst_rd,
   output logic                             ticket_ack_rd_fifo,

   // be signals
   output logic [DATA_W/8*2**N-1:0]         be_rdData = 'b0,
   input logic                              clk,
   input logic                              nrst
   );

   logic                                    ticket_ack_wr_fifo_n = '0;
   logic                                    ticket_ack_rd_fifo_n = '0;
   logic                                    ticket_ack_wr_fifo_i = '0;
   logic                                    ticket_ack_rd_fifo_i = '0;
   // constants
   parameter COL_W = 8;
   parameter N_COL = 4*2**N;
   // port b signals & ticketing system {
   logic unsigned [(M+L)-1:0]               addrb = '0;
   logic [CACHE_N_BANKS*DATA_W/8-1:0]       web = '0;
   logic [CACHE_N_BANKS*DATA_W-1:0]         dib = '0;
   logic                                    rd_fifo_din_v_p0 = '0;
   logic                                    rd_fifo_din_v_p1 = '0;
   logic unsigned [(M+L)-1:0]               rd_fifo_rqst_addr_inc = '0;
   logic unsigned [(M+L)-1:0]               rd_fifo_rqst_addr_inc_n = '0;
   logic [CACHE_N_BANKS*DATA_W-1:0]         wr_fifo_dout_d0 = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_vec = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_wr_vec = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_rd_vec = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_vec_d0 = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_wr_vec_d0 = '0;
   logic [2**BURST_WORDS_W/CACHE_N_BANKS-1:0] ticket_ack_rd_vec_d0 = '0;
   logic                                      ticket_ack_vec_n = '0;
   logic                                      ticket_ack_wr_vec_n = '0;
   logic                                      ticket_ack_rd_vec_n = '0;
   logic [(M+L)-1:0]                          wr_fifo_rqst_addr_d0 = '0;
   logic [(M+L)-1:0]                          rd_fifo_rqst_addr_d0 = '0;
   // }
   // be signals {
   logic                                      be_we = '0;
   logic [DATA_W/8*2**N-1:0]                  be_rdData_n = '0;
   // }
   assign ticket_ack_wr_fifo = ticket_ack_wr_fifo_i;
   assign ticket_ack_rd_fifo = ticket_ack_rd_fifo_i;

   // cache port b control {
   always_ff @(posedge clk) begin
      ticket_ack_wr_fifo_i <= ticket_ack_wr_fifo_n;
      ticket_ack_rd_fifo_i <= ticket_ack_rd_fifo_n;
      wr_fifo_dout_d0 <= wr_fifo_dout;
      ticket_ack_vec <= {ticket_ack_vec_n, ticket_ack_vec[$high(ticket_ack_vec):1]};
      ticket_ack_vec_d0 <= ticket_ack_vec;
      ticket_ack_wr_vec <= {ticket_ack_wr_vec_n, ticket_ack_wr_vec[$high(ticket_ack_wr_vec):1]};
      ticket_ack_wr_vec_d0 <= ticket_ack_wr_vec;
      ticket_ack_rd_vec <= {ticket_ack_rd_vec_n, ticket_ack_rd_vec[$high(ticket_ack_rd_vec):1]};
      ticket_ack_rd_vec_d0 <= ticket_ack_rd_vec;
      wr_fifo_rqst_addr_d0 <= wr_fifo_rqst_addr;
      rd_fifo_rqst_addr_d0 <= rd_fifo_rqst_addr;
      // write path
      web <= '0;
      dib <= wr_fifo_dout_d0;
      if (ticket_ack_wr_vec_d0 != '0) begin
         addrb <= wr_fifo_rqst_addr_d0;
         web <= '1;
      end
      // read path
      be_we <= 'b0;
      rd_fifo_din_v_p1 <= '0;
      if (ticket_ack_rd_vec_d0 != '0) begin
         addrb <= rd_fifo_rqst_addr_inc;
         rd_fifo_din_v_p1 <= 'b1;
         be_we <= 'b1;
      end
      rd_fifo_din_v_p0 <= rd_fifo_din_v_p1;
      rd_fifo_din_v <= rd_fifo_din_v_p0;
      if (!nrst) begin
         rd_fifo_rqst_addr_inc <= '0;
      end else begin
         rd_fifo_rqst_addr_inc <= rd_fifo_rqst_addr_inc_n;
      end
   end // always_comb

   always_comb begin
      ticket_ack_wr_fifo_n <= '0;
      ticket_ack_rd_fifo_n <= '0;
      ticket_ack_vec_n <= 'b0;
      ticket_ack_wr_vec_n <= 'b0;
      ticket_ack_rd_vec_n <= 'b0;
      rd_fifo_rqst_addr_inc_n <= rd_fifo_rqst_addr_inc;
      if (ticket_ack_rd_vec_d0[$high(ticket_ack_rd_vec_d0):1] != '0) begin
         rd_fifo_rqst_addr_inc_n <= rd_fifo_rqst_addr_inc + 1;
      end else begin
         rd_fifo_rqst_addr_inc_n <= rd_fifo_rqst_addr_d0;
      end
      if (ticket_rqst_wr && ticket_ack_vec[$high(ticket_ack_vec):1] == '0) begin
         ticket_ack_wr_fifo_n <= 'b1;
         ticket_ack_vec_n <= 'b1;
         ticket_ack_wr_vec_n <= 'b1;
      end else if (ticket_rqst_rd && ticket_ack_vec[$high(ticket_ack_vec):1] == '0) begin
         ticket_ack_rd_fifo_n <= 'b1;
         ticket_ack_vec_n <= 'b1;
         ticket_ack_rd_vec_n <= 'b1;
      end
   end

   // be {
   always_ff @(posedge clk) begin
      static logic [0:2**(M+L)-1][2**N*DATA_W/8-1:0] be = '0;
      if (ena) begin
         for (int j = 0; j < 2**N*DATA_W/8; j++) begin
            if (wea[j]) begin
               be[$unsigned(addra)][j] <= 'b1;
            end
         end
      end
      be_rdData_n <= be[$unsigned(addrb)];
      // when read from axi (i.e. write back to gmem)
      if (be_we) begin
         be[$unsigned(addrb)] <= '0;
      end
      if (enb) begin
         be_rdData <= be_rdData_n;
      end
   end
   // }

   // // cache byte enabel memory
   // cache_be_bram i_cache_be_inst
   //   (
   //    .clka(clk),
   //    .ena(ena),
   //    .wea(),
   //    .addra(addra),
   //    .dina(),
   //    .douta(),
   //    .clkb(clk),
   //    .enb(enb),
   //    .web(be_we),
   //    .addrb(addrb),
   //    .dinb('d0),
   //    .doutb(be_rdData)
   //    );

   // cache memory
   cache_bram i_cache_inst
     (
      .clka(clk),
      .ena(ena),
      .wea(wea),
      .addra(addra),
      .dina(dia),
      .douta(doa),
      .clkb(clk),
      .enb(enb),
      .web(web),
      .addrb(addrb),
      .dinb(dib),
      .doutb(dob)
      );

endmodule
