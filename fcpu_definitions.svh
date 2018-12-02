`ifndef FCPU_DEFINITIONS_SVH
`define FCPU_DEFINITIONS_SVH

package fcpu_pkg;

   localparam DATA_W = 32;
   localparam CRAM_ADDR_W = 22;
   localparam RSV_ID_W = 5;
   localparam REG_ADDR_W = 5;
   localparam PHT_ADDR_W = 18; // pattern history table
   localparam PHT_DATA_W = 2;
   localparam GMEM_ADDR_W = 20;
   localparam CDB_W = RSV_ID_W+DATA_W; // common data bus

   localparam INSTR_W = 6;
   localparam INSTR_POS = 26;

   localparam N_STATIONS_W = 5;

   localparam N_ROB_W = 4;     // reorder buffer size = 16

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
      logic [REG_ADDR_W-1:0]   dst_reg;
      logic [INSTR_W-1:0]      opcode;
      logic [DATA_W-1:0]       content;
   } station_t;

   const logic [INSTR_W-1:0] I_ADD     = 'b000001;
   const logic [INSTR_W-1:0] I_BLE     = 'b000010;
   const logic [INSTR_W-1:0] I_ADDI    = 'b000011;
   const logic [INSTR_W-1:0] I_SUB     = 'b000100;
   const logic [INSTR_W-1:0] I_BLEI    = 'b000101;
   const logic [INSTR_W-1:0] I_SUBI    = 'b000110;
   const logic [INSTR_W-1:0] I_LOADR   = 'b001000;
   const logic [INSTR_W-1:0] I_STORER  = 'b001001;
   const logic [INSTR_W-1:0] I_LOADRF  = 'b001010;
   const logic [INSTR_W-1:0] I_STORERF = 'b001011;
   const logic [INSTR_W-1:0] I_FABS    = 'b001100;
   const logic [INSTR_W-1:0] I_FLOOR   = 'b001110;
   const logic [INSTR_W-1:0] I_FNEG    = 'b001111;
   const logic [INSTR_W-1:0] I_BLT     = 'b010000;
   const logic [INSTR_W-1:0] I_BLTF    = 'b010001;
   const logic [INSTR_W-1:0] I_BLTI    = 'b010010;
   const logic [INSTR_W-1:0] I_BEQ     = 'b010011;
   const logic [INSTR_W-1:0] I_BEQF    = 'b010100;
   const logic [INSTR_W-1:0] I_BEQI    = 'b010101;
   const logic [INSTR_W-1:0] I_SLI     = 'b011001;
   const logic [INSTR_W-1:0] I_SL      = 'b011010;
   const logic [INSTR_W-1:0] I_SRL     = 'b011011;
   const logic [INSTR_W-1:0] I_SRA     = 'b011100;
   const logic [INSTR_W-1:0] I_JMP     = 'b011110;
   const logic [INSTR_W-1:0] I_JMPR    = 'b100000;
   const logic [INSTR_W-1:0] I_SAVE    = 'b100010;
   const logic [INSTR_W-1:0] I_SETI1   = 'b100100;
   const logic [INSTR_W-1:0] I_SETI2   = 'b100101;
   const logic [INSTR_W-1:0] I_SETF1   = 'b100110;
   const logic [INSTR_W-1:0] I_SETF2   = 'b100111;
   const logic [INSTR_W-1:0] I_LOAD    = 'b101000;
   const logic [INSTR_W-1:0] I_STORE   = 'b101010;
   const logic [INSTR_W-1:0] I_INPUT   = 'b101100;
   const logic [INSTR_W-1:0] I_INPUTF  = 'b101101;
   const logic [INSTR_W-1:0] I_OUTPUT  = 'b110000;
   const logic [INSTR_W-1:0] I_LOADB   = 'b110010;
   const logic [INSTR_W-1:0] I_LOADBF  = 'b110011;
   const logic [INSTR_W-1:0] I_STOREB  = 'b110100;
   const logic [INSTR_W-1:0] I_STOREBF = 'b110101;
   const logic [INSTR_W-1:0] I_LOADF   = 'b110110;
   const logic [INSTR_W-1:0] I_STOREF  = 'b110111;
   const logic [INSTR_W-1:0] I_I2F     = 'b111000;
   const logic [INSTR_W-1:0] I_F2I     = 'b111001;
   const logic [INSTR_W-1:0] I_ADDF    = 'b111010;
   const logic [INSTR_W-1:0] I_SUBF    = 'b111011;
   const logic [INSTR_W-1:0] I_MULF    = 'b111100;
   const logic [INSTR_W-1:0] I_INVF    = 'b111101;
   const logic [INSTR_W-1:0] I_SQRTF   = 'b111110;

endpackage

`endif
