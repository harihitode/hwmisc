`ifndef FCPU_DEFINITIONS_SVH
`define FCPU_DEFINITIONS_SVH

package fcpu_pkg;

   localparam DATA_W = 32;
   localparam CRAM_ADDR_W = 14;
   localparam RSV_ID_W = 5;
   localparam REG_ADDR_W = 5;
   localparam PHT_ADDR_W = 18; // pattern history table
   localparam PHT_DATA_W = 2;

   localparam N_CU_STATIONS_W = 6;
   localparam CACHE_N_BANKS_W = 2;
   localparam CACHE_N_BANKS = 2**CACHE_N_BANKS_W;
   localparam GMEM_ADDR_W = 28;
   localparam GMEM_WORD_ADDR_W = GMEM_ADDR_W - 2;
   // localparam GMEM_N_BANK_W = 2; // Bitwidth of the number of words of a single AXI data interface, i.e. the global memory git bus
   localparam GMEM_N_BANK_W = 0;
   localparam GMEM_N_BANK = 2**GMEM_N_BANK_W;
   localparam GMEM_DATA_W = GMEM_N_BANK * DATA_W;
   localparam BURST_WORDS_W = 4;
   localparam BURST_WORDS = 2**BURST_WORDS_W;
   localparam BURST_W = BURST_WORDS_W - GMEM_N_BANK_W; // burst width in number of transfers on the axi bus
   localparam N_RD_FIFOS_TAG_MANAGER_W = 0; // one fifo to store data read out of global memory for each tag manager (now, only 0 makes sense)
   localparam FINISH_FIFO_ADDR_W = 3; // Bitwidth of the fifo depth to mark dirty cache lines to be cleared at the end
   localparam RD_FIFO_N_BURSTS_W = 1;
   localparam RD_FIFO_W = BURST_W + RD_FIFO_N_BURSTS_W;
   localparam ID_WIDTH = 4;    // Bitwidth of the read & write id channels of AXI4
   localparam CDB_W = RSV_ID_W+DATA_W; // common data bus

   localparam N_RECEIVERS_CU_W = 6; // Bitwidth of # of receivers inside the global memory controller per CU. (6-N_CU_W) will lead to 64 receivers whatever the # of CU is.
   localparam N_RECEIVERS_CU = 2**N_RECEIVERS_CU_W;
   localparam N_RECEIVERS_W = N_RECEIVERS_CU_W;
   localparam N_RECEIVERS = 2**N_RECEIVERS_W;

   localparam INSTR_W = 6;
   localparam INSTR_POS = 26;

   localparam N_STATIONS_W = 5;

   localparam N_ROB_W = 4;     // reorder buffer size = 16

   localparam BRAM36kb_ADDR_W = 10;
   localparam BRMEM_ADDR_W = BRAM36kb_ADDR_W; // default 10
   localparam N_RD_PORTS = 4;
   // 2**N words = cache col size (in bram physically)
   localparam N = CACHE_N_BANKS_W;
   // 2**L cols = # of cols in one cache line
   localparam L = BURST_WORDS_W - N;
   // 2**M blocks = block size
   localparam M = BRMEM_ADDR_W - L;
   localparam TAG_W = GMEM_WORD_ADDR_W - M - L - N;

   localparam ATOMIC_IMPLEMENT = 1;
   localparam WRITE_PHASE_W = 1;
   // number of MSBs of the receiver index in the global memory controller which will be selected to write. These bits increments always.
   // This incrmenetation should help to balance serving the receivers
   localparam RCV_PRIORITY_W = 3;

   typedef enum logic [2:0] {
                             commit_integer,
                             commit_float,
                             commit_mem_integer,
                             commit_mem_float,
                             commit_branch
                             } commit_type_t;

   typedef struct packed {
      logic [N_STATIONS_W-1:0] station_id;
      logic                    valid;
      logic                    ready;
      logic                    invalidate;
      logic [REG_ADDR_W-1:0]   dst_reg;
      logic [INSTR_W-1:0]      opcode;
      logic [DATA_W-1:0]       content;
   } station_t;

   const logic [INSTR_W-1:0]   I_NOP     = 'b000000;
   const logic [INSTR_W-1:0]   I_LOAD    = 'b000001;
   const logic [INSTR_W-1:0]   I_LOADR   = 'b000010;
   const logic [INSTR_W-1:0]   I_STORE   = 'b000011;
   const logic [INSTR_W-1:0]   I_STORER  = 'b000100;
   const logic [INSTR_W-1:0]   I_SAVE    = 'b000101;
   const logic [INSTR_W-1:0]   I_BLT     = 'b000110;
   const logic [INSTR_W-1:0]   I_BEQ     = 'b000111;
   const logic [INSTR_W-1:0]   I_JMP     = 'b001000;
   const logic [INSTR_W-1:0]   I_JMPR    = 'b001001;
   const logic [INSTR_W-1:0]   I_SETI1   = 'b001010;
   const logic [INSTR_W-1:0]   I_SETI2   = 'b001011;
   const logic [INSTR_W-1:0]   I_ADD     = 'b001100;
   const logic [INSTR_W-1:0]   I_SUB     = 'b001101;
   const logic [INSTR_W-1:0]   I_ADDI    = 'b001110;
   const logic [INSTR_W-1:0]   I_SUBI    = 'b001111;
   const logic [INSTR_W-1:0]   I_SL      = 'b010000;
   const logic [INSTR_W-1:0]   I_SRL     = 'b010001;
   const logic [INSTR_W-1:0]   I_SRA     = 'b010010;
   const logic [INSTR_W-1:0]   I_OR      = 'b010011;
   const logic [INSTR_W-1:0]   I_AND     = 'b010100;
   const logic [INSTR_W-1:0]   I_XOR     = 'b010101;

   const logic [INSTR_W-1:0]   I_OUTPUT  = 'b100000;
   const logic [INSTR_W-1:0]   I_LOADB   = 'b100010;
   const logic [INSTR_W-1:0]   I_STOREB  = 'b100011;
   const logic [INSTR_W-1:0]   I_INPUT   = 'b100100;
   const logic [INSTR_W-1:0]   I_AADD    = 'b110001;
   const logic [INSTR_W-1:0]   I_AMAX    = 'b110010;
   const logic [INSTR_W-1:0]   I_STORET  = 'b110110;
   const logic [INSTR_W-1:0]   I_STORETB = 'b110111;
   const logic [INSTR_W-1:0]   I_LOADT   = 'b111000;
   const logic [INSTR_W-1:0]   I_LOADTB  = 'b111001;

   // const logic [INSTR_W-1:0]   I_BLE     = 'b000010;
   // const logic [INSTR_W-1:0]   I_BLEI    = 'b000101;
   // const logic [INSTR_W-1:0]   I_LOADRF  = 'b001010;
   // const logic [INSTR_W-1:0]   I_STORERF = 'b001011;
   // const logic [INSTR_W-1:0]   I_FABS    = 'b001100;
   // const logic [INSTR_W-1:0]   I_FLOOR   = 'b001110;
   // const logic [INSTR_W-1:0]   I_FNEG    = 'b001111;
   // const logic [INSTR_W-1:0]   I_BLTF    = 'b010001;
   // const logic [INSTR_W-1:0]   I_BLTI    = 'b010010;
   // const logic [INSTR_W-1:0]   I_BEQF    = 'b010100;
   // const logic [INSTR_W-1:0]   I_BEQI    = 'b010101;
   // const logic [INSTR_W-1:0]   I_SLI     = 'b011001;
   // const logic [INSTR_W-1:0]   I_SETF1   = 'b100110;
   // const logic [INSTR_W-1:0]   I_SETF2   = 'b100111;
   // const logic [INSTR_W-1:0]   I_INPUTF  = 'b101101;
   // const logic [INSTR_W-1:0]   I_LOADBF  = 'b110011;
   // const logic [INSTR_W-1:0]   I_STOREBF = 'b110101;
   // const logic [INSTR_W-1:0]   I_LOADF   = 'b110110;
   // const logic [INSTR_W-1:0]   I_STOREF  = 'b110111;
   // const logic [INSTR_W-1:0]   I_I2F     = 'b111000;
   // const logic [INSTR_W-1:0]   I_F2I     = 'b111001;
   // const logic [INSTR_W-1:0]   I_ADDF    = 'b111010;
   // const logic [INSTR_W-1:0]   I_SUBF    = 'b111011;
   // const logic [INSTR_W-1:0]   I_MULF    = 'b111100;
   // const logic [INSTR_W-1:0]   I_INVF    = 'b111101;
   // const logic [INSTR_W-1:0]   I_SQRTF   = 'b111110;

endpackage

`endif
