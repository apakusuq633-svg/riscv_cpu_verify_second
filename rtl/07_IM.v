// ============================================================================
// RISC-V 寄存器堆 (32 × 32-bit)
// x0 (寄存器 0) 硬连线为 0: 读始终返回 0, 写被忽略
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
    output reg [31:0] read_data1,       // 读数据1
    output reg [31:0] read_data2        // 读数据2
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
            for (i = 1; i < 32; i = i + 1) begin
                register_file[i] <= 32'h0000_0000;
            end
            // x0 始终为 0, 不需要复位
            register_file[0] <= 32'h0000_0000;
        end else if (we3 && rd != 5'b00000) begin
            register_file[rd] <= write_data;
        end
    end

    // 读操作: x0 始终返回 0, 转发优先
    always @(posedge clk or negedge rst) begin
        read_data1 = (ForwardingA && rs1 != 5'b00000) ? ALU_result :
                     (rs1 == 5'b00000) ? 32'h0000_0000 : register_file[rs1];
        read_data2 = (ForwardingB && rs2 != 5'b00000) ? ALU_result :
                     (rs2 == 5'b00000) ? 32'h0000_0000 : register_file[rs2];
    end

endmodule
