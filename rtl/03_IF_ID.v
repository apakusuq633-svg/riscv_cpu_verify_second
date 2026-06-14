module IF_ID(
    input wire clk,
    input wire rst,
    input wire [31:0] PC_in,
    input wire [31:0] instruction_in,
    input wire stall,
    input wire flush,                   // 分支跳转清空
    output reg [31:0] PC_out,
    output reg [31:0] instruction_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC_out <= 32'h0000_0000;
            instruction_out <= 32'h0000_0000;
        end else if (flush) begin
            // 分支跳转后: 插入 NOP (addi x0, x0, 0)
            PC_out <= 32'h0000_0000;
            instruction_out <= 32'h00000013;
        end else if (!stall) begin
            PC_out <= PC_in;
            instruction_out <= instruction_in;
        end
    end
endmodule
