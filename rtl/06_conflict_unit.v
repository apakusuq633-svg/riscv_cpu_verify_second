// ============================================================================
// 流水线冲突控制单元 — 综合冒险检测 + 数据转发
// 合并自: hazard_detection + forwarding_unit
// ============================================================================
module conflict_unit(
    // ===== 冒险检测接口 (ID阶段) =====
    input wire MemReadE,            // ID/EX 阶段是否为 load 指令
    input wire [4:0] rd_E,         // ID/EX 阶段目标寄存器
    input wire [4:0] rs1_D,        // IF/ID 阶段源寄存器1
    input wire [4:0] rs2_D,        // IF/ID 阶段源寄存器2

    // ===== 转发接口 (EX阶段) =====
    input wire [4:0] rs1_E,        // ID/EX 阶段源寄存器1
    input wire [4:0] rs2_E,        // ID/EX 阶段源寄存器2
    input wire [4:0] rd_M,         // EX/MEM 阶段目标寄存器
    input wire RegWriteM,          // EX/MEM 阶段寄存器写使能
    input wire [4:0] rd_W,         // MEM/WB 阶段目标寄存器
    input wire RegWriteW,          // MEM/WB 阶段寄存器写使能

    // ===== 冒险控制输出 =====
    output reg stall,              // 暂停 IF/ID 阶段
    output reg flush,              // 清空 ID/EX 阶段（插入 NOP）

    // ===== 转发控制输出 =====
    // 00: 不转发    01: 从 MEM/WB 转发    10: 从 EX/MEM 转发
    output reg [1:0] ForwardAE,    // ALU 操作数 A 转发选择
    output reg [1:0] ForwardBE     // ALU 操作数 B 转发选择
);

    // ========================================================================
    // 冒险检测：load-use 数据冲突 → stall + flush
    // ========================================================================
    always @(*) begin
        stall = 1'b0;
        flush = 1'b0;

        // 若 ID/EX 阶段是 lw，且目标寄存器是 IF/ID 阶段某源寄存器 → 冲突
        if (MemReadE && (rd_E != 5'b00000)) begin
            if ((rd_E == rs1_D) || (rd_E == rs2_D)) begin
                stall = 1'b1;
                flush = 1'b1;
            end
        end
    end

    // ========================================================================
    // 数据转发：EX/MEM 或 MEM/WB 结果旁路到 EX 阶段 ALU 输入
    // 优先级：EX/MEM > MEM/WB（最新数据优先）
    // ========================================================================
    always @(*) begin
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;

        // --- ForwardA ---
        if (RegWriteM && (rd_M != 5'b00000) && (rd_M == rs1_E))
            ForwardAE = 2'b10;          // EX/MEM 转发（最高优先级）
        else if (RegWriteW && (rd_W != 5'b00000) && (rd_W == rs1_E))
            ForwardAE = 2'b01;          // MEM/WB 转发

        // --- ForwardB ---
        if (RegWriteM && (rd_M != 5'b00000) && (rd_M == rs2_E))
            ForwardBE = 2'b10;          // EX/MEM 转发（最高优先级）
        else if (RegWriteW && (rd_W != 5'b00000) && (rd_W == rs2_E))
            ForwardBE = 2'b01;          // MEM/WB 转发
    end

endmodule
