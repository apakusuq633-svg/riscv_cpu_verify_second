// ============================================================================
// RISC-V 立即数扩展单元
// 支持 I / S / B / U / J 五种立即数格式
// ============================================================================
module sign_extend(
    input wire [2:0] ImmSrc,        // 立即数格式选择
    input wire [11:0] imm_I,        // I-type: inst[31:20]
    input wire [11:0] imm_S,        // S-type: {inst[31:25], inst[11:7]}
    input wire [11:0] imm_B,        // B-type: {inst[31], inst[7], inst[30:25], inst[11:8]}
    input wire [19:0] imm_U,        // U-type: inst[31:12]
    input wire [19:0] imm_J,        // J-type: {inst[31], inst[19:12], inst[20], inst[30:21]}
    output reg [31:0] imm_32
);
    always @(*) begin
        case (ImmSrc)
            // I-type: 12-bit 符号扩展
            3'b000: imm_32 = {{20{imm_I[11]}}, imm_I};

            // S-type: 12-bit 符号扩展
            3'b001: imm_32 = {{20{imm_S[11]}}, imm_S};

            // B-type: 13-bit 符号扩展 (追加隐式 bit0=0, 实现 ×2)
            3'b010: imm_32 = {{19{imm_B[11]}}, imm_B[11:0], 1'b0};

            // U-type: 高 20 位, 低 12 位为零
            3'b011: imm_32 = {imm_U, 12'b0};

            // J-type: 21-bit 符号扩展 (追加隐式 bit0=0, 实现 ×2)
            3'b100: imm_32 = {{11{imm_J[19]}}, imm_J[19:0], 1'b0};

            default: imm_32 = 32'h0000_0000;
        endcase
    end
endmodule
