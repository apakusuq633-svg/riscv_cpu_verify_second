// ============================================================================
// RISC-V EX 阶段
// 包含: 转发多路器, ALU, 分支/跳转目标计算
// LUI: SrcA=0, AUIPC: SrcA=PC
// JAL/JALR: 返回地址 = PC+4 (通过 WB 阶段写回)
// ============================================================================
module EX_stage(
    input wire clk,
    input wire rst,
    input wire [31:0] RD1,
    input wire [31:0] RD2,
    input wire [31:0] imm,
    input wire [31:0] PC,
    input wire [3:0] ALUControl,
    input wire ALUSrc,
    input wire LUI,
    input wire AUIPC,
    input wire [1:0] ForwardAE,
    input wire [1:0] ForwardBE,
    input wire [31:0] ALU_result_M,
    input wire [31:0] write_data_W,

    output wire [31:0] ALU_result,
    output wire zero_flag,
    output wire [31:0] branch_target,
    output wire [31:0] jump_target,
    output wire [31:0] pc_plus_4,
    output wire [31:0] store_data
);
    wire [31:0] SrcA_fwd;
    wire [31:0] SrcA;
    wire [31:0] SrcB_nomux;
    wire [31:0] SrcB;
    assign store_data = SrcB_nomux;
    // A 端口转发 mux
    mux_3to1 #(.WIDTH(32)) mux_A(
        .in0(RD1),
        .in1(write_data_W),
        .in2(ALU_result_M),
        .sel(ForwardAE),
        .out(SrcA_fwd)
    );

    // SrcA 选择: LUI → 0, AUIPC → PC, 否则 → 转发结果
    assign SrcA = LUI  ? 32'b0 :
                  AUIPC ? PC :
                  SrcA_fwd;

    // B 端口转发 mux
    mux_3to1 #(.WIDTH(32)) mux_B(
        .in0(RD2),
        .in1(write_data_W),
        .in2(ALU_result_M),
        .sel(ForwardBE),
        .out(SrcB_nomux)
    );

    // ALUSrc 选择: 立即数 或 寄存器
    assign SrcB = ALUSrc ? imm : SrcB_nomux;

    // 目标地址计算
    assign branch_target = PC + imm;          // B-type: PC + 符号扩展偏移
    assign jump_target   = PC + imm;          // J-type: PC + J-type 偏移
    assign pc_plus_4     = PC + 32'd4;        // JAL/JALR 返回地址

    // ALU
    alu alu_unit(
        .clk(clk),
        .rst(rst),
        .SrcAE(SrcA),
        .SrcBE(SrcB),
        .ALUControlE(ALUControl),
        .ALUResultE(ALU_result)
    );

    // zero 标志: 用于 B-type 分支判断 (BEQ/BNE)
    assign zero_flag = (ALU_result == 32'b0) ? 1'b1 : 1'b0;
endmodule
