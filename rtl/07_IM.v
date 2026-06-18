// ============================================================================
// RISC-V 寄存器堆 (32 × 32-bit)
// x0 (寄存器 0) 硬连线为 0: 读始终返回 0, 写被忽略
// 读操作使用 3 选 1 复用器实现: 正常读 / 同周期旁路 / x0 硬连线
// ============================================================================
module IM(
    input wire clk,
    input wire rst,
    input wire we3,                     // 写使能
    input wire [4:0] rs1,               // 源寄存器1
    input wire [4:0] rs2,               // 源寄存器2
    input wire [4:0] rd,                // 目的寄存器
    input wire [31:0] write_data,       // 写数据
    input wire ForwardingA,             // A端口转发使能            
    input wire ForwardingB,             // B端口转发使能            
    input wire [31:0] ALU_result,       // 转发数据 (来自 ALU)      
    output wire [31:0] read_data1,      // 读数据1
    output wire [31:0] read_data2       // 读数据2
);
    reg [31:0] register_file [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            register_file[i] = 32'h0000_0000;
        end
    end

    // 写操作: x0 始终为 0, 写入被忽略
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                register_file[i] <= 32'h0000_0000;
            end
            register_file[0] <= 32'h0000_0000; // 确保 x0 始终为 0
        end else if (we3 && rd != 5'b00000) begin
            register_file[rd] <= write_data;
        end
    end

    // ========================================================================
    // 组合读 — 寄存器堆读口使用 3 选 1 复用器
    //
    //  sel = 00 : 正常读    → register_file[rs]
    //  sel = 01 : 同周期旁路  → write_data (WB 阶段写同一个 rd，读口直通)
    //  sel = 10 : forwarding    → ALU_result (EX 阶段写同一个 rd，读口直通)
    //  sel = 11 : x0 硬连线  → 32'h0 (rs == x0 或 旁路目标为 x0)
    //
    // 选择逻辑: x0 检测优先级最高，其次同周期旁路，最后默认读寄存器
    // ========================================================================

    // --- 读数据1: 寄存器堆原始输出 (组合) ---
    wire [31:0] rf_rd1;
    assign rf_rd1 = register_file[rs1];

    // --- 读数据1 选择信号 ---
    wire [1:0] rd1_sel;
    assign rd1_sel = (rs1 == 5'b00000)               ? 2'b11    // x0 → 输出 0
                   : (we3 && rd == rs1 && rd != 5'b0) ? 2'b01     // 同周期旁路
                   : (ForwardingA)                     ? 2'b10     // forwarding
                                                      : 2'b00;    // 正常读

    mux_3to1 #(.WIDTH(32)) mux_read1 (
        .in0(rf_rd1),
        .in1(write_data),
        .in2(ALU_result),
        .sel(rd1_sel),
        .out(read_data1)
    );

    // --- 读数据2: 寄存器堆原始输出 (组合) ---
    wire [31:0] rf_rd2;
    assign rf_rd2 = register_file[rs2];

    // --- 读数据2 选择信号 ---
    wire [1:0] rd2_sel;
    assign rd2_sel = (rs2 == 5'b00000)               ? 2'b11    // x0 → 输出 0
                   : (we3 && rd == rs2 && rd != 5'b0) ? 2'b01     // 同周期旁路
                   : (ForwardingB)                     ? 2'b10     // forwarding
                                                      : 2'b00;    // 正常读

    mux_3to1 #(.WIDTH(32)) mux_read2 (
        .in0(rf_rd2),
        .in1(write_data),
        .in2(ALU_result),
        .sel(rd2_sel),
        .out(read_data2)
    );

endmodule
