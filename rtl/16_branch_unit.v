// ============================================================================
// RISC-V 分支/跳转单元
// 根据 Branch / Jump 信号以及 ALU 结果决定下一条 PC
// JAL: 目标 = jump_target (PC + J-type imm)
// JALR: 目标 = ALU_result & ~1 (rs1 + I-type imm, 最低位清零)
// B-type: 根据 funct3 和条件标志决定是否分支
// ============================================================================
module branch_unit(
    input wire BranchM,                 // B-type 分支指令
    input wire JumpM,                   // JAL / JALR 跳转指令
    input wire JALRM,                   // JALR (跳转目标来自 ALU_result)
    input wire [2:0] funct3,            // funct3 区分分支类型
    input wire zero_flag,               // ALU 结果为零标志 (rs1 - rs2 = 0 → BEQ)
    input wire [31:0] ALU_result,       // ALU 结果 (用于 SLT/SLTU 结果 和 JALR 目标)
    input wire [31:0] branch_target,    // B-type 分支目标 (PC + imm)
    input wire [31:0] jump_target,      // J-type 跳转目标 (PC + imm)
    input wire [31:0] pc_plus_4,        // PC + 4 (默认下一条指令)

    output reg [31:0] next_pc,
    output reg branch_taken
);
    // RISC-V B-type funct3 编码
    localparam BEQ  = 3'b000;
    localparam BNE  = 3'b001;
    localparam BLT  = 3'b100;
    localparam BGE  = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;

    wire take_branch;
    reg  branch_cond;

    // 根据 funct3 判定分支条件
    // zero_flag 来自减法结果: zero_flag=1 表示 rs1==rs2
    always @(*) begin
        case (funct3)
            BEQ:  branch_cond = zero_flag;                       // rs1 == rs2
            BNE:  branch_cond = ~zero_flag;                      // rs1 != rs2
            // BLT/BGE/BLTU/BGEU 使用 ALU 的 SLT/SLTU 结果
            // ALU_result[0] = 1 表示 SrcA < SrcB
            BLT:  branch_cond = ALU_result[0];                   // rs1 < rs2 (signed)
            BGE:  branch_cond = ~ALU_result[0];                  // rs1 >= rs2 (signed)
            BLTU: branch_cond = ALU_result[0];                   // rs1 < rs2 (unsigned)
            BGEU: branch_cond = ~ALU_result[0];                  // rs1 >= rs2 (unsigned)
            default: branch_cond = 1'b0;
        endcase
    end

    assign take_branch = BranchM && branch_cond;

    // 跳转优先于分支
    always @(*) begin
        if (JumpM) begin
            if (JALRM) begin
                // JALR: 目标 = (rs1 + offset) & ~1 (最低位清零保证对齐)
                next_pc = ALU_result & 32'hFFFFFFFE;
            end else begin
                // JAL: 目标 = PC + offset
                next_pc = jump_target;
            end
            branch_taken = 1'b1;
        end else if (take_branch) begin
            next_pc = branch_target;
            branch_taken = 1'b1;
        end else begin
            next_pc = pc_plus_4;
            branch_taken = 1'b0;
        end
    end

endmodule
