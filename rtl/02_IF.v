// ============================================================================
// RISC-V 指令存储器 (256 × 32-bit)
// 通过 $readmemh 从 hex 文件加载程序
// 用法: vvp sim/cpu_tb.vvp +hexfile=tests/hex/program.hex
// ============================================================================
module IF(
    input wire clk,
    input wire rst,
    input wire [31:0] pc,
    input wire we,                       // 写使能, 用于加载指令
    input wire [31:0] write_data,        // 写入的指令数据
    output reg [31:0] instruction
);
    reg [31:0] instruction_memory [0:255];
    reg [1023:0] hexfile_path;
    reg file_loaded;
    integer i;

    initial begin
        // 初始化全部指令存储器为零
        for (i = 0; i < 256; i = i + 1) begin
            instruction_memory[i] = 32'h0000_0000;
        end

        // ================================================================
        // 从 hex 文件加载测试程序
        // 支持 +hexfile=<path> 运行时参数, 未指定时使用默认路径
        // ================================================================
        file_loaded = 1'b0;

        // 尝试读取 +hexfile 参数
        if ($value$plusargs("hexfile=%s", hexfile_path)) begin
            $readmemh(hexfile_path, instruction_memory);
            $display("IF: Loaded program from %s", hexfile_path);
            file_loaded = 1'b1;
        end

        // 回退: 尝试默认路径
        if (!file_loaded) begin
            $readmemh("tests/hex/program.hex", instruction_memory);
            $display("IF: Loaded program from tests/hex/program.hex (default)");
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instruction <= 32'h0000_0000;
        end else begin
            if (we) begin
                instruction_memory[pc[9:2]] <= write_data;
            end else begin
                instruction <= instruction_memory[pc[9:2]];
            end
        end
    end

endmodule
