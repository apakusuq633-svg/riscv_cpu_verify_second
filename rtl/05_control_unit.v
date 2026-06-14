// ============================================================================
// RISC-V RV32I 控制单元
// 根据 7-bit opcode 产生数据通路控制信号
// ============================================================================
module control_unit(
    input wire [6:0] opcode,            // RISC-V 7-bit opcode (bits 6:0)
    input wire [2:0] funct3,            // funct3 用于分支类型判断
    output reg RegWrite,                // 寄存器堆写使能
    output reg MemtoReg,                // 1: 写内存数据到寄存器, 0: 写 ALU 结果
    output reg MemWrite,                // 数据存储器写使能
    output reg MemRead,                 // 数据存储器读使能
    output reg [1:0] ALUOp,             // ALU 操作选择 (2-bit)
    output reg ALUSrc,                  // 1: ALU 源来自立即数, 0: 来自寄存器
    output reg Branch,                  // 分支指令 (B-type)
    output reg Jump,                    // 跳转指令 (JAL / JALR)
    output reg [2:0] ImmSrc,            // 立即数格式选择 (I/S/B/U/J-type)
    output reg LUI,                     // LUI 指令标志 (SrcA=0)
    output reg AUIPC,                   // AUIPC 指令标志 (SrcA=PC)
    output reg JALR                      // JALR 指令标志 (跳转目标 = ALU_result & ~1)
);
    // RISC-V RV32I opcode 定义
    localparam OP_RTYPE   = 7'b0110011; // R-type: add, sub, and, or, xor, slt, sltu, sll, srl, sra
    localparam OP_ITYPE   = 7'b0010011; // I-type ALU: addi, andi, ori, xori, slti, sltiu, slli, srli, srai
    localparam OP_LOAD    = 7'b0000011; // I-type load: lw
    localparam OP_STORE   = 7'b0100011; // S-type: sw
    localparam OP_BRANCH  = 7'b1100011; // B-type: beq, bne, blt, bge, bltu, bgeu
    localparam OP_JAL     = 7'b1101111; // J-type: jal
    localparam OP_JALR    = 7'b1100111; // I-type: jalr
    localparam OP_LUI     = 7'b0110111; // U-type: lui
    localparam OP_AUIPC   = 7'b0010111; // U-type: auipc

    always @(*) begin
        // 默认值
        RegWrite = 1'b0;
        MemtoReg = 1'b0;
        MemWrite = 1'b0;
        MemRead  = 1'b0;
        ALUOp    = 2'b00;
        ALUSrc   = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;
        ImmSrc   = 3'b000;
        LUI      = 1'b0;
        AUIPC    = 1'b0;
        JALR     = 1'b0;

        case (opcode)
            // ---- R-type: add, sub, and, or, xor, slt, sltu, sll, srl, sra ----
            OP_RTYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;   // 由 funct3+funct7 决定 ALU 操作
            end

            // ---- I-type ALU: addi, andi, ori, xori, slti, sltiu, slli, srli, srai ----
            OP_ITYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;   // 由 funct3+funct7 决定 ALU 操作
                ALUSrc   = 1'b1;
                ImmSrc   = 3'b000;  // I-type 立即数格式
            end

            // ---- Load: lw rd, imm(rs1) ----
            OP_LOAD: begin
                RegWrite = 1'b1;
                MemtoReg = 1'b1;    // 内存数据 → 寄存器
                MemRead  = 1'b1;
                ALUSrc   = 1'b1;
                ImmSrc   = 3'b000;  // I-type 立即数格式
            end

            // ---- Store: sw rs2, imm(rs1) ----
            OP_STORE: begin
                MemWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSrc   = 3'b001;  // S-type 立即数格式
            end

            // ---- Branch: beq, bne, blt, bge, bltu, bgeu ----
            // BEQ/BNE → SUB; BLT/BGE → SLT; BLTU/BGEU → SLTU
            OP_BRANCH: begin
                Branch   = 1'b1;
                ImmSrc   = 3'b010;  // B-type 立即数格式
                ALUSrc   = 1'b0;    // ALU 源来自寄存器
                case (funct3)
                    3'b000, 3'b001: ALUOp = 2'b01;   // BEQ/BNE: SUB
                    default:         ALUOp = 2'b11;   // BLT/BGE/BLTU/BGEU: branch comparison
                endcase
            end

            // ---- JAL: jal rd, offset ----
            OP_JAL: begin
                RegWrite = 1'b1;
                Jump     = 1'b1;
                ImmSrc   = 3'b100;  // J-type 立即数格式
            end

            // ---- JALR: jalr rd, imm(rs1) ----
            OP_JALR: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                Jump     = 1'b1;
                JALR     = 1'b1;
                ImmSrc   = 3'b000;  // I-type 立即数格式
            end

            // ---- LUI: lui rd, imm20 ----
            OP_LUI: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSrc   = 3'b011;  // U-type 立即数格式
                LUI      = 1'b1;    // SrcA = 0
            end

            // ---- AUIPC: auipc rd, imm20 ----
            OP_AUIPC: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSrc   = 3'b011;  // U-type 立即数格式
                AUIPC    = 1'b1;    // SrcA = PC
            end
        endcase
    end

endmodule
