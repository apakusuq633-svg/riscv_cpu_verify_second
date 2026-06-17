module MEM_stage(
    input wire clk,
    input wire rst,
    input wire MemWriteM,
    input wire MemReadM,
    input wire [2:0] funct3M,
    input wire [31:0] ALU_result,
    input wire [31:0] RD2,

    output wire [31:0] read_data
);
    data_mem data_mem_unit(
        .clk(clk),
        .rst(rst),
        .we(MemWriteM),
        .re(MemReadM),
        .funct3(funct3M),
        .alu_result(ALU_result),
        .write_data(RD2),
        .read_data(read_data)
    );
endmodule