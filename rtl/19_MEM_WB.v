// ============================================================================
// MEM/WB 流水线寄存器 (RISC-V)
// ============================================================================
module MEM_WB(
    input wire clk,
    input wire rst,
    // ---- MEM 阶段控制信号 ----
    input wire RegWriteM,
    input wire MemtoRegM,
    input wire JumpM,
    // ---- MEM 阶段数据信号 ----
    input wire [31:0] ALU_result,
    input wire [31:0] read_data,
    input wire [31:0] pc_plus_4,
    input wire [4:0] rd,

    // ---- WB 阶段控制信号 ----
    output reg RegWriteW,
    output reg MemtoRegW,
    output reg JumpW,
    // ---- WB 阶段数据信号 ----
    output reg [31:0] ALU_result_out,
    output reg [31:0] read_data_out,
    output reg [31:0] pc_plus_4_out,
    output reg [4:0] rd_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteW      <= 1'b0;
            MemtoRegW      <= 1'b0;
            JumpW          <= 1'b0;
            ALU_result_out <= 32'h0000_0000;
            read_data_out  <= 32'h0000_0000;
            pc_plus_4_out  <= 32'h0000_0000;
            rd_out         <= 5'b00000;
        end else begin
            RegWriteW      <= RegWriteM;
            MemtoRegW      <= MemtoRegM;
            JumpW          <= JumpM;
            ALU_result_out <= ALU_result;
            read_data_out  <= read_data;
            pc_plus_4_out  <= pc_plus_4;
            rd_out         <= rd;
        end
    end
endmodule
