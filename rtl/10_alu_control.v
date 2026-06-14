// ============================================================================
// RISC-V ALU 控制单元
// 根据 ALUOp + funct3 + funct7 产生 4-bit ALU 控制信号
// ============================================================================
module alu_control (
    input wire [1:0] ALUOp,             // 控制单元输出的 ALU 操作码
    input wire [2:0] funct3,            // funct3 字段 (bits 14:12)
    input wire [6:0] funct7,            // funct7 字段 (bits 31:25)
    output reg [3:0] ALUControl         // ALU 控制信号 (4-bit)
);
    // ALU 操作编码
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    always @(*) begin
        case (ALUOp)
            // Load / Store / AUIPC / JAL / LUI: 强制加法
            2'b00: ALUControl = ALU_ADD;

            // Branch: 强制减法 (用于比较)
            2'b01: ALUControl = ALU_SUB;

            // R-type / I-type ALU: 由 funct3 + funct7[30] 决定
            2'b10: begin
                case (funct3)
                    3'b000: // ADD / SUB
                        ALUControl = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001: ALUControl = ALU_SLL;   // SLL / SLLI
                    3'b010: ALUControl = ALU_SLT;   // SLT / SLTI
                    3'b011: ALUControl = ALU_SLTU;  // SLTU / SLTIU
                    3'b100: ALUControl = ALU_XOR;   // XOR / XORI
                    3'b101: // SRL/SRA 或 SRLI/SRAI
                        ALUControl = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: ALUControl = ALU_OR;    // OR / ORI
                    3'b111: ALUControl = ALU_AND;   // AND / ANDI
                    default: ALUControl = ALU_ADD;
                endcase
            end

            // Branch comparison: BLT/BGE → SLT, BLTU/BGEU → SLTU
            2'b11: begin
                case (funct3)
                    3'b100, 3'b101: ALUControl = ALU_SLT;   // BLT/BGE: signed compare
                    3'b110, 3'b111: ALUControl = ALU_SLTU;  // BLTU/BGEU: unsigned compare
                    default: ALUControl = ALU_SUB;
                endcase
            end

            default: ALUControl = ALU_ADD;
        endcase
    end

endmodule
