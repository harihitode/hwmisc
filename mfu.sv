`timescale 1 ns / 1 ps
`include "fcpu_definitions.svh"
import fcpu_pkg::*;

module memory_functional_unit
  #(localparam N_OPERANDS = 3)
   (
    input logic                                                     clk,

    input logic                                                     i_valid,
    input logic [RSV_ID_W+INSTR_W+N_OPERANDS*(RSV_ID_W+DATA_W)-1:0] i_data,
    input logic [N_OPERANDS-1:0]                                    i_filled,
    output logic                                                    i_ready,

    input logic                                                     store_commit_valid,
    input logic                                                     store_commit_invalidate,
    input logic [RSV_ID_W-1:0]                                      store_commit_id,

    input logic [CDB_W-1:0]                                         cdb,
    input                                                           cdb_valid,

    output logic [CDB_W-1:0]                                        o_cdb,
    output logic                                                    o_cdb_valid,
    input logic                                                     o_cdb_ready,

    output logic                                                    o_valid,
    output logic [INSTR_W-1:0]                                      o_opcode,
    output logic [RSV_ID_W-1:0]                                     o_rsv_id,
    output logic [DATA_W-1:0]                                       o_address,
    output logic [DATA_W-1:0]                                       o_data,
    input logic                                                     o_ready,

    input logic                                                     nrst
    );

   localparam STORE_BUFFER_SIZE = 4;
   typedef struct                                                   packed {
      logic [RSV_ID_W-1:0]     rob_id;
      logic [INSTR_W-1:0]      opcode;
      logic                    valid;
      logic                    invalidate;
      logic                    committed;
      logic                    data_ready;
      logic                    addr_ready;
      logic [RSV_ID_W-1:0]     data_rob_id;
      logic [DATA_W-1:0]       data;
      logic [DATA_W-1:0]       address;
      logic                    override;
   } store_buffer_t;
   store_buffer_t head_buffer;

   int                         head = 0, tail = 0;
   int                         head_n = 0, tail_n = 0;

   wire                        i_ready_preaddress;
   wire                        i_ready_storebuffer;
   wire                        address_valid;
   wire                        p_address_valid;
   typedef struct              packed {
      logic [RSV_ID_W-1:0]     rob_id;
      logic [INSTR_W-1:0]      opcode;
      logic [DATA_W-1:0]       address_left;
      logic [DATA_W-1:0]       address_right;
   } pre_address_t;

   typedef struct              packed {
      logic [RSV_ID_W-1:0]     rob_id;
      logic [INSTR_W-1:0]      opcode;
      logic [DATA_W-1:0]       computed_address;
      logic [DATA_W-1:0]       address_left;
      logic [DATA_W-1:0]       address_right;
   } post_address_t;

   pre_address_t p_address;
   post_address_t p_computed_address = 'b0;
   post_address_t address;
   logic                       address_ready = 'b0;
   wire                        p_address_ready;
   logic                       address_store = 'b0;
   logic                       load_bypassing = 'b0;
   logic [STORE_BUFFER_SIZE-1:0] load_bypassing_vec = 'b0;
   logic                         load_forwarding = 'b0;

   store_buffer_t [STORE_BUFFER_SIZE-1:0] store_buffer = 'b0;
   store_buffer_t [STORE_BUFFER_SIZE-1:0] store_buffer_n = 'b0;

   always_comb begin
      o_rsv_id <= 'b0;
      o_data <= 'b0;
      o_address <= 'b0;
      o_valid <= 'b0;
      o_opcode <= 'b0;
      // priority is STORE > LOAD
      if (address_valid &&
          load_bypassing &&
          (address.opcode == I_LOAD ||
           address.opcode == I_LOADB ||
           address.opcode == I_LOADR ||
           address.opcode == I_INPUT)) begin
         o_rsv_id <= address.rob_id;
         o_opcode <= address.opcode;
         o_data <= 'b0;
         o_address <= address.computed_address;
         o_valid <= 'b1;
      end else if (head_buffer.valid & head_buffer.data_ready &
          head_buffer.addr_ready & head_buffer.committed) begin
         o_rsv_id <= head_buffer.rob_id;
         o_opcode <= head_buffer.opcode;
         o_data <= head_buffer.data;
         o_address <= head_buffer.address;
         o_valid <= 'b1;
      end
   end // always_comb

   always_comb begin
      load_forwarding <= 'b0;
      o_cdb <= 'b0;
      o_cdb_valid <= 'b0;
      if (address_valid && !address_store) begin
         for (int i = 0; i < STORE_BUFFER_SIZE; i++) begin
            if (address.computed_address == store_buffer[i].address &&
                address.computed_address != '1 &&
                store_buffer[i].data_ready &&
                !store_buffer[i].override) begin
               load_forwarding <= 'b1;
               o_cdb <= {address.rob_id, store_buffer[i].data};
               o_cdb_valid <= 'b1;
               break;
            end
         end
      end
   end // always_comb

   always_comb begin
      case (address.opcode)
        I_STORE, I_STOREB, I_STORER,
//        I_STOREF, I_STOREBF, I_STORERF,
        I_OUTPUT : begin
           address_store <= 'b1;
        end
        default : begin
           address_store <= 'b0;
        end
      endcase
   end

   // for critical path
   always_comb begin
      if (address_store) begin
         address_ready <= 'b1;
      end else if (address_valid &&
                   (address.opcode == I_LOAD ||
                    address.opcode == I_LOADB ||
                    address.opcode == I_LOADR ||
                    address.opcode == I_INPUT)) begin
         address_ready <= (load_bypassing & o_ready) |
                          (load_forwarding & o_cdb_ready);
      end else begin
         address_ready <= 'b0;
      end
   end

   assign i_ready_storebuffer = (head_buffer.valid && (head == tail)) ? 'b0 : 'b1;
   assign i_ready = i_ready_preaddress & i_ready_storebuffer;

   logic store_buffer_push = 'b0;
   logic store_buffer_pop = 'b0;

   always_comb begin
      store_buffer_push <= 'b0;
      if (i_valid && i_ready) begin
         case (i_data[3*(DATA_W+RSV_ID_W)+:INSTR_W])
           I_STORE, I_STOREB, I_STORER,
//           I_STOREF, I_STOREBF, I_STORERF,
           I_OUTPUT : begin
              store_buffer_push <= 'b1;
           end
         endcase
      end
   end

   always_comb begin
      store_buffer_pop <= 'b0;
      if ((o_valid && o_ready) || head_buffer.invalidate) begin
         case (o_opcode)
           I_STORE, I_STOREB, I_STORER,
//           I_STOREF, I_STOREBF, I_STORERF,
           I_OUTPUT : begin
              store_buffer_pop <= 'b1;
           end
         endcase
      end
   end

   always_comb head_countup : begin
      if (store_buffer_pop) begin
         if (head == STORE_BUFFER_SIZE-1) begin
            head_n <= 0;
         end else begin
            head_n <= head + 'b1;
         end
      end else begin
         head_n <= head;
      end
   end

   always_comb tail_countup : begin
      if (store_buffer_push) begin
         if (tail == STORE_BUFFER_SIZE-1) begin
            tail_n <= 0;
         end else begin
            tail_n <= tail + 'b1;
         end
      end else begin
         tail_n <= tail;
      end
   end

   always_ff @(posedge clk) begin
      if (nrst) begin
         head <= head_n;
         head_buffer <= store_buffer[head_n];
         tail <= tail_n;
         store_buffer <= store_buffer_n;
      end else begin
         head <= 0;
         head_buffer <= 'b0;
         tail <= 0;
         store_buffer <= 'b0;
      end
   end

   generate begin for (genvar i = 0; i < STORE_BUFFER_SIZE; i++) begin
      always_comb begin
         store_buffer_n[i] <= store_buffer[i];
         if (store_buffer_push) begin
            if (i_valid && i_ready && i == tail && !store_buffer[i].valid) begin
               store_buffer_n[i].valid       <= 'b1;
               store_buffer_n[i].opcode      <= i_data[3*(DATA_W+RSV_ID_W)+:INSTR_W];
               store_buffer_n[i].rob_id      <= i_data[3*(DATA_W+RSV_ID_W)+INSTR_W+:RSV_ID_W];
               store_buffer_n[i].data        <= i_data[2*(DATA_W+RSV_ID_W)+:DATA_W];
               store_buffer_n[i].data_rob_id <= i_data[2*(DATA_W+RSV_ID_W)+DATA_W+:RSV_ID_W];
               store_buffer_n[i].data_ready  <= i_filled[2];
               store_buffer_n[i].invalidate  <= 'b0;
               store_buffer_n[i].override    <= 'b0;
            end
         end
         if (store_buffer[i].valid &&
             cdb_valid &&
             store_buffer[i].data_rob_id == cdb[DATA_W+:RSV_ID_W]) begin
            store_buffer_n[i].data <= cdb[DATA_W-1:0];
            store_buffer_n[i].data_ready <= 'b1;
         end
         if (store_buffer[i].valid &&
             address_valid &&
             address.rob_id == store_buffer[i].rob_id) begin
            store_buffer_n[i].address <= address.computed_address;
            store_buffer_n[i].addr_ready <= 'b1;
         end else if (address_valid && address_store &&
                      address[2*DATA_W+:DATA_W] == store_buffer[i].address) begin
            store_buffer_n[i].override <= 'b1;
         end
         if (store_buffer[i].valid &&
             store_commit_valid &&
             store_commit_id == store_buffer[i].rob_id) begin
            store_buffer_n[i].committed <= 'b1;
            store_buffer_n[i].invalidate <= store_commit_invalidate;
         end
         if (store_buffer[i].valid &&
             store_buffer_pop && i == head) begin
            store_buffer_n[i] <= 'b0;
         end
      end
   end end
   endgenerate

   fifo
     #(.FIFO_DEPTH_W(4),
       .DATA_W(RSV_ID_W+INSTR_W+3*(DATA_W)))
   address_buffer
     (
      .clk(clk),
      .a_data(p_computed_address),
      .a_valid(p_address_valid),
      .a_ready(p_address_ready),
      .b_data(address),
      .b_valid(address_valid),
      .b_ready(address_ready),
      .nrst(nrst)
      );

   reservation_station
     #(.N_OPERANDS(2),
       .N_STATIONS_W(4))
   preaddress_buffer
     (
      .clk(clk),

      .i_valid(i_valid),
      .i_data({
               i_data[3*(RSV_ID_W+DATA_W)+:RSV_ID_W+INSTR_W],
               {i_data[RSV_ID_W+DATA_W+DATA_W+:RSV_ID_W], i_data[RSV_ID_W+DATA_W+:DATA_W]},
               {i_data[DATA_W+:RSV_ID_W], i_data[0+:DATA_W]}
               }),
      .i_filled(i_filled[1:0]),
      .i_ordered('b1),
      .i_ready(i_ready_preaddress),

      .o_valid(p_address_valid),
      .o_data(p_address),
      .o_ready(p_address_ready),

      .cdb_valid(cdb_valid),
      .cdb(cdb),
      .nrst(nrst)
      );

   generate begin for (genvar i = 0; i < STORE_BUFFER_SIZE; i++) begin
      always_comb begin
         if (store_buffer[i].valid &&
             address.computed_address == store_buffer[i].address) begin
            load_bypassing_vec[i] <= 'b0;
         end else begin
            load_bypassing_vec[i] <= 'b1;
         end
      end
   end end
   endgenerate

   always_comb begin
      if (address_valid && !address_store) begin
         load_bypassing <= &load_bypassing_vec;
      end else begin
         load_bypassing <= 'b0;
      end
   end // always_comb

   always_comb begin
      p_computed_address.rob_id <= p_address.rob_id;
      p_computed_address.opcode <= p_address.opcode;
      p_computed_address.address_left <= p_address.address_left;
      p_computed_address.address_right <= p_address.address_right;

      if (p_address.opcode == I_STOREB ||
          p_address.opcode == I_LOADB) begin
         p_computed_address.computed_address <= p_address.address_left - p_address.address_right;
      end else begin
         p_computed_address.computed_address <= p_address.address_left + p_address.address_right;
      end
   end

endmodule
