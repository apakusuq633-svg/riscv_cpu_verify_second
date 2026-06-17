// ============================================================================
// RISC-V RV32I 5-stage Pipeline CPU Top Module
// 流水线阶段: IF → ID → EX → MEM → WB
// ============================================================================
module CPU_top(
    input wire clk,
    input wire rst
);
    // ========================================================================
    // IF Stage
    // ========================================================================
    wire [31:0] PC;
    wire [31:0] next_pc;
    wire [31:0] instruction_IF;

    // ========================================================================
    // IF_ID Latch
    // ========================================================================
    wire [31:0] PC_ID;
    wire [31:0] instruction_ID;
    wire stall;

    // ========================================================================
    // ID Stage — instruction decode
    // ========================================================================
    wire [6:0] opcode;
    wire [4:0] rs1, rs2, rd;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [11:0] imm_I, imm_S, imm_B;
    wire [19:0] imm_U, imm_J;

    // Control signals (ID stage outputs)
    wire RegWriteD, MemtoRegD, MemWriteD, MemReadD, BranchD, JumpD, LUID, AUIPCD, JALRD;
    wire [1:0] ALUOpD;
    wire ALUSrcD;
    wire [2:0] ImmSrcD;

    // Register file outputs
    wire [31:0] RD1, RD2;

    // Sign extended immediate
    wire [31:0] imm_extended;

    // ========================================================================
    // ID_EX Latch
    // ========================================================================
    wire [31:0] RD1_EX, RD2_EX;
    wire [31:0] imm_EX;
    wire [31:0] PC_EX;
    wire [4:0] rs1_EX, rs2_EX, rd_EX;
    wire [2:0] funct3_EX;
    wire [6:0] funct7_EX;
    wire RegWriteE, MemtoRegE, MemWriteE, MemReadE, ALUSrcE, BranchE, JumpE, LUIE, AUIPCE, JALRE;
    wire [1:0] ALUOpE;
    wire [2:0] ImmSrcE;

    // ========================================================================
    // Conflict Unit (Hazard Detection + Data Forwarding)
    // ========================================================================
    wire flush_ID_EX;
    wire [1:0] ForwardAE, ForwardBE;

    // ========================================================================
    // Branch flush: EX 阶段判定分支跳转后, 清空 IF_ID 和 ID_EX
    // ========================================================================
    wire flush_branch;
    assign flush_branch = branch_taken;

    wire flush_ID_EX_combined;
    assign flush_ID_EX_combined = flush_ID_EX | flush_branch;

    // ========================================================================
    // ALU Control
    // ========================================================================
    wire [3:0] ALUControl;

    // ========================================================================
    // EX Stage
    // ========================================================================
    wire [31:0] ALU_result_EX;
    wire zero_flag_EX;
    wire [31:0] branch_target_EX;
    wire [31:0] jump_target_EX;
    wire [31:0] pc_plus_4_EX;
    wire [31:0] store_data_EX;
    // ========================================================================
    // EX_MEM Latch
    // ========================================================================
    wire [31:0] ALU_result_MEM;
    wire [31:0] RD2_MEM;
    wire [4:0] rd_MEM;
    wire [31:0] branch_target_MEM;
    wire [31:0] jump_target_MEM;
    wire [31:0] pc_plus_4_MEM;
    wire zero_flag_MEM;
    wire [2:0] funct3_MEM;
    wire RegWriteM, MemtoRegM, MemWriteM, MemReadM, BranchM, JumpM, JALRM;

    // ========================================================================
    // MEM Stage
    // ========================================================================
    wire [31:0] read_data_MEM;

    // ========================================================================
    // MEM_WB Latch
    // ========================================================================
    wire [31:0] ALU_result_WB;
    wire [31:0] read_data_WB;
    wire [31:0] pc_plus_4_WB;
    wire [4:0] rd_WB;
    wire RegWriteW, MemtoRegW, JumpW;

    // ========================================================================
    // WB Stage
    // ========================================================================
    wire [31:0] write_data;

    // ========================================================================
    // Branch Unit
    // ========================================================================
    wire branch_taken;
    wire [31:0] branch_target_pc;

    // Sequential PC
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = PC + 32'd4;

  assign next_pc = branch_taken ? branch_target_pc :
                 stall        ? PC :
                                pc_plus_4;

    // ========================================================================
    // == IF Stage ==
    // ========================================================================
    PC pc_module(
        .clk(clk),
        .rst(rst),
        .next_pc(next_pc),
        .pc(PC)
    );

    IF if_module(
        .clk(clk),
        .rst(rst),
        .pc(PC),
        .we(1'b0),                      // 指令存储器只读
        .write_data(32'h0000_0000),
        .instruction(instruction_IF)
    );

    // ========================================================================
    // == IF_ID Latch ==
    // ========================================================================
    IF_ID if_id_latch(
        .clk(clk),
        .rst(rst),
        .PC_in(PC),
        .instruction_in(instruction_IF),
        .stall(stall),
        .flush(flush_branch),            // 分支跳转时清空 IF_ID
        .PC_out(PC_ID),
        .instruction_out(instruction_ID)
    );

    // ========================================================================
    // == ID Stage ==
    // ========================================================================
    ID_stage id_decode(
        .instruction(instruction_ID),
        .opcode(opcode),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .funct7(funct7),
        .imm_I(imm_I),
        .imm_S(imm_S),
        .imm_B(imm_B),
        .imm_U(imm_U),
        .imm_J(imm_J)
    );

    control_unit ctrl_unit(
        .opcode(opcode),
        .funct3(funct3),
        .RegWrite(RegWriteD),
        .MemtoReg(MemtoRegD),
        .MemWrite(MemWriteD),
        .MemRead(MemReadD),
        .ALUOp(ALUOpD),
        .ALUSrc(ALUSrcD),
        .Branch(BranchD),
        .Jump(JumpD),
        .ImmSrc(ImmSrcD),
        .LUI(LUID),
        .AUIPC(AUIPCD),
        .JALR(JALRD)
    );

    // Register file (x0 hardwired to 0)
    IM reg_file(
        .clk(clk),
        .rst(rst),
        .we3(RegWriteW),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd_WB),
        .write_data(write_data),
        .ForwardingA(1'b0),             // 顶层不转发，由 EX 阶段 mux 处理
        .ForwardingB(1'b0),
        .ALU_result(32'h0000_0000),
        .read_data1(RD1),
        .read_data2(RD2)
    );

    // Sign extend: I/S/B/U/J 五种格式
    sign_extend sign_ext(
        .ImmSrc(ImmSrcD),
        .imm_I(imm_I),
        .imm_S(imm_S),
        .imm_B(imm_B),
        .imm_U(imm_U),
        .imm_J(imm_J),
        .imm_32(imm_extended)
    );

    // ========================================================================
    // == Conflict Unit (Hazard + Forwarding) ==
    // ========================================================================
    conflict_unit conflict_ctrl(
        // Hazard detection
        .MemReadE(MemReadE),
        .rd_E(rd_EX),
        .rs1_D(rs1),
        .rs2_D(rs2),
        // Forwarding
        .rs1_E(rs1_EX),
        .rs2_E(rs2_EX),
        .rd_M(rd_MEM),
        .RegWriteM(RegWriteM),
        .rd_W(rd_WB),
        .RegWriteW(RegWriteW),
        // Outputs
        .stall(stall),
        .flush(flush_ID_EX),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE)
    );

    // ========================================================================
    // == ID_EX Latch ==
    // ========================================================================
    ID_EX id_ex_latch(
        .clk(clk),
        .rst(rst),
        .flush(flush_ID_EX_combined),
        // Control in
        .RegWriteD(RegWriteD),
        .MemtoRegD(MemtoRegD),
        .MemWriteD(MemWriteD),
        .MemReadD(MemReadD),
        .ALUOpD(ALUOpD),
        .ALUSrcD(ALUSrcD),
        .BranchD(BranchD),
        .JumpD(JumpD),
        .ImmSrcD(ImmSrcD),
        .LUID(LUID),
        .AUIPCD(AUIPCD),
        .JALRD(JALRD),
        // Data in
        .PC_in(PC_ID),
        .RD1(RD1),
        .RD2(RD2),
        .sign_ext_imm(imm_extended),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .funct7(funct7),
        // Control out
        .RegWriteE(RegWriteE),
        .MemtoRegE(MemtoRegE),
        .MemWriteE(MemWriteE),
        .MemReadE(MemReadE),
        .ALUOpE(ALUOpE),
        .ALUSrcE(ALUSrcE),
        .BranchE(BranchE),
        .JumpE(JumpE),
        .ImmSrcE(ImmSrcE),
        .LUIE(LUIE),
        .AUIPCE(AUIPCE),
        .JALRE(JALRE),
        // Data out
        .PC_out(PC_EX),
        .RD1_out(RD1_EX),
        .RD2_out(RD2_EX),
        .imm_out(imm_EX),
        .rs1_out(rs1_EX),
        .rs2_out(rs2_EX),
        .rd_out(rd_EX),
        .funct3_out(funct3_EX),
        .funct7_out(funct7_EX)
    );

    // ========================================================================
    // == ALU Control Unit ==
    // ========================================================================
    alu_control alu_ctrl(
        .ALUOp(ALUOpE),
        .funct3(funct3_EX),
        .funct7(funct7_EX),
        .ALUSrc(ALUSrcE),
        .ALUControl(ALUControl)
    );

    // ========================================================================
    // == EX Stage ==
    // ========================================================================
    EX_stage ex_stage(
        .clk(clk),
        .rst(rst),
        .RD1(RD1_EX),
        .RD2(RD2_EX),
        .imm(imm_EX),
        .PC(PC_EX),
        .ALUControl(ALUControl),
        .ALUSrc(ALUSrcE),
        .LUI(LUIE),
        .AUIPC(AUIPCE),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .ALU_result_M(ALU_result_MEM),
        .write_data_W(write_data),
        .ALU_result(ALU_result_EX),
        .zero_flag(zero_flag_EX),
        .branch_target(branch_target_EX),
        .jump_target(jump_target_EX),
        .pc_plus_4(pc_plus_4_EX),
        .store_data(store_data_EX)
    );

    // ========================================================================
    // == EX_MEM Latch ==
    // ========================================================================
    EX_MEM ex_mem_latch(
        .clk(clk),
        .rst(rst),
        // Control in
        .RegWriteE(RegWriteE),
        .MemtoRegE(MemtoRegE),
        .MemWriteE(MemWriteE),
        .MemReadE(MemReadE),
        .BranchE(BranchE),
        .JumpE(JumpE),
        .JALRE(JALRE),
        // Data in
        .ALU_result(ALU_result_EX),
        .RD2_E(store_data_EX),
        .rd_E(rd_EX),                   // RISC-V: rd is always the destination
        .branch_target(branch_target_EX),
        .jump_target(jump_target_EX),
        .pc_plus_4(pc_plus_4_EX),
        .zero_flag(zero_flag_EX),
        .funct3(funct3_EX),
        // Control out
        .RegWriteM(RegWriteM),
        .MemtoRegM(MemtoRegM),
        .MemWriteM(MemWriteM),
        .MemReadM(MemReadM),
        .BranchM(BranchM),
        .JumpM(JumpM),
        .JALRM(JALRM),
        // Data out
        .ALU_result_out(ALU_result_MEM),
        .RD2_out(RD2_MEM),
        .rd_out(rd_MEM),
        .branch_target_out(branch_target_MEM),
        .jump_target_out(jump_target_MEM),
        .pc_plus_4_out(pc_plus_4_MEM),
        .zero_flag_out(zero_flag_MEM),
        .funct3_out(funct3_MEM)
    );

    // ========================================================================
    // == Branch / Jump Unit ==
    // ========================================================================
    branch_unit branch_ctrl(
        .Branch(BranchE),
        .Jump(JumpE),
        .JALR(JALRE),
        .funct3(funct3_EX),
        .zero_flag(zero_flag_EX),
        .ALU_result(ALU_result_EX),
        .branch_target(branch_target_EX),
        .jump_target(jump_target_EX),
        .target_pc(branch_target_pc),
        .branch_taken(branch_taken)
    );

    // ========================================================================
    // == MEM Stage ==
    // ========================================================================
   MEM_stage mem_stage(
    .clk(clk),
    .rst(rst),
    .MemWriteM(MemWriteM),
    .MemReadM(MemReadM),
    .funct3M(funct3_MEM),
    .ALU_result(ALU_result_MEM),
    .RD2(RD2_MEM),
    .read_data(read_data_MEM)
    );

    // ========================================================================
    // == MEM_WB Latch ==
    // ========================================================================
    MEM_WB mem_wb_latch(
        .clk(clk),
        .rst(rst),
        // Control in
        .RegWriteM(RegWriteM),
        .MemtoRegM(MemtoRegM),
        .JumpM(JumpM),
        // Data in
        .ALU_result(ALU_result_MEM),
        .read_data(read_data_MEM),
        .pc_plus_4(pc_plus_4_MEM),
        .rd(rd_MEM),
        // Control out
        .RegWriteW(RegWriteW),
        .MemtoRegW(MemtoRegW),
        .JumpW(JumpW),
        // Data out
        .ALU_result_out(ALU_result_WB),
        .read_data_out(read_data_WB),
        .pc_plus_4_out(pc_plus_4_WB),
        .rd_out(rd_WB)
    );

    // ========================================================================
    // == WB Stage ==
    // ========================================================================
    WB wb_stage(
        .alu_result(ALU_result_WB),
        .read_data(read_data_WB),
        .pc_plus_4(pc_plus_4_WB),
        .MemtoReg(MemtoRegW),
        .Jump(JumpW),
        .write_data(write_data)
    );

endmodule
