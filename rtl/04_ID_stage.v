module ID_stage(
    input wire [31:0] instruction,
    // RISC-V instruction fields
    output wire [6:0] opcode,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    // Raw immediate fields for sign_extend
    output wire [11:0] imm_I,       // I-type: inst[31:20]
    output wire [11:0] imm_S,       // S-type: {inst[31:25], inst[11:7]}
    output wire [11:0] imm_B,       // B-type: {inst[31], inst[7], inst[30:25], inst[11:8]}
    output wire [19:0] imm_U,       // U-type: inst[31:12]
    output wire [19:0] imm_J        // J-type: {inst[31], inst[19:12], inst[20], inst[30:21]}
);
    // RISC-V 指令字段提取 (RV32I 编码)
    // opcode:  bits [6:0]
    // rd:      bits [11:7]
    // funct3:  bits [14:12]
    // rs1:     bits [19:15]
    // rs2:     bits [24:20]
    // funct7:  bits [31:25]
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // I-type immediate: inst[31:20]
    assign imm_I = instruction[31:20];

    // S-type immediate: {inst[31:25], inst[11:7]}
    assign imm_S = {instruction[31:25], instruction[11:7]};

    // B-type immediate: {inst[31], inst[7], inst[30:25], inst[11:8]}
    assign imm_B = {instruction[31], instruction[7], instruction[30:25], instruction[11:8]};

    // U-type immediate: inst[31:12]
    assign imm_U = instruction[31:12];

    // J-type immediate: {inst[31], inst[19:12], inst[20], inst[30:21]}
    assign imm_J = {instruction[31], instruction[19:12], instruction[20], instruction[30:21]};

endmodule
