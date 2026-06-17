// ============================================================================
// RISC-V 指令存储器
// 组合读：保证 instruction 和 PC 在同一周期对齐
// ============================================================================
module IF(
    input wire clk,
    input wire rst,
    input wire [31:0] pc,
    input wire we,
    input wire [31:0] write_data,
    output reg [31:0] instruction
);
    reg [31:0] instruction_memory [0:255];
    reg [1023:0] hexfile_path;
    reg file_loaded;
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            instruction_memory[i] = 32'h0000_0013;   // 默认 NOP
        end

        file_loaded = 1'b0;

        if ($value$plusargs("hexfile=%s", hexfile_path)) begin
            $readmemh(hexfile_path, instruction_memory);
            $display("IF: Loaded program from %s", hexfile_path);
         
            file_loaded = 1'b1;
        end

        if (!file_loaded) begin
            $readmemh("tests/hex/program.hex", instruction_memory);
            $display("IF: Loaded program from tests/hex/program.hex (default)");
        end
    end

    // 写指令存储器，一般测试时不用
    always @(posedge clk) begin
        if (we) begin
            instruction_memory[pc[9:2]] <= write_data;
        end
    end

    // 组合读：关键修改点
    always @(*) begin
        if (rst) begin
            instruction = 32'h0000_0013;   // NOP
        end else begin
            instruction = instruction_memory[pc[9:2]];
        end
    end

endmodule