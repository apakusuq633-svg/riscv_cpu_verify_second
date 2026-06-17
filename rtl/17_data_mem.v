module data_mem(
    input wire clk,
    input wire rst,
    input wire we,
    input wire re,
    input wire [2:0] funct3,
    input wire [31:0] alu_result,
    input wire [31:0] write_data,
    output reg [31:0] read_data
);
    integer i;

    // 字节寻址内存：1024 bytes
    reg [7:0] data_memory [0:1023];

    wire [9:0] addr;
    assign addr = alu_result[9:0];

    // 初始化
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            data_memory[i] = 8'h00;
        end
    end

    // 写操作：小端序
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 1024; i = i + 1) begin
                data_memory[i] <= 8'h00;
            end
        end else if (we) begin
            case (funct3)
                3'b000: begin
                    // sb
                    data_memory[addr] <= write_data[7:0];
                end

                3'b001: begin
                    // sh
                    data_memory[addr]     <= write_data[7:0];
                    data_memory[addr + 1] <= write_data[15:8];
                end

                3'b010: begin
                    // sw
                    data_memory[addr]     <= write_data[7:0];
                    data_memory[addr + 1] <= write_data[15:8];
                    data_memory[addr + 2] <= write_data[23:16];
                    data_memory[addr + 3] <= write_data[31:24];
                end

                default: begin
                    // 不支持的 store 类型，不写
                end
            endcase
        end
    end

    // 读操作：小端序
    always @(*) begin
        if (rst || !re) begin
            read_data = 32'h0000_0000;
        end else begin
            case (funct3)
                3'b000: begin
                    // lb：符号扩展 byte
                    read_data = {{24{data_memory[addr][7]}}, data_memory[addr]};
                end

                3'b001: begin
                    // lh：符号扩展 halfword
                    read_data = {{16{data_memory[addr + 1][7]}},
                                 data_memory[addr + 1],
                                 data_memory[addr]};
                end

                3'b010: begin
                    // lw
                    read_data = {data_memory[addr + 3],
                                 data_memory[addr + 2],
                                 data_memory[addr + 1],
                                 data_memory[addr]};
                end

                3'b100: begin
                    // lbu：零扩展 byte
                    read_data = {24'h000000, data_memory[addr]};
                end

                3'b101: begin
                    // lhu：零扩展 halfword
                    read_data = {16'h0000,
                                 data_memory[addr + 1],
                                 data_memory[addr]};
                end

                default: begin
                    read_data = 32'h0000_0000;
                end
            endcase
        end
    end
endmodule