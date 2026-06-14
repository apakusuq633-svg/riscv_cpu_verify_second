// ============================================================================
// RISC-V ALU
// 支持 RV32I 所需的所有算术/逻辑运算
// ============================================================================
module alu(
    input wire clk,
    input wire rst,
    input wire [31:0] SrcAE,
    input wire [31:0] SrcBE,
    input wire [3:0] ALUControlE,
    output reg [31:0] ALUResultE
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
        if (rst)
            ALUResultE <= 32'h0000_0000;
        else begin
            case (ALUControlE)
                ALU_ADD:  ALUResultE <= SrcAE + SrcBE;                                          // ADD
                ALU_SUB:  ALUResultE <= SrcAE - SrcBE;                                          // SUB
                ALU_AND:  ALUResultE <= SrcAE & SrcBE;                                          // AND
                ALU_OR:   ALUResultE <= SrcAE | SrcBE;                                          // OR
                ALU_XOR:  ALUResultE <= SrcAE ^ SrcBE;                                          // XOR
                ALU_SLL:  ALUResultE <= SrcAE << SrcBE[4:0];                                    // SLL
                ALU_SRL:  ALUResultE <= SrcAE >> SrcBE[4:0];                                    // SRL
                ALU_SRA:  ALUResultE <= $signed(SrcAE) >>> SrcBE[4:0];                          // SRA
                ALU_SLT:  ALUResultE <= ($signed(SrcAE) < $signed(SrcBE)) ? 32'b1 : 32'b0;      // SLT
                ALU_SLTU: ALUResultE <= (SrcAE < SrcBE) ? 32'b1 : 32'b0;                        // SLTU
                default:  ALUResultE <= 32'h0000_0000;
            endcase
        end
    end

endmodule
