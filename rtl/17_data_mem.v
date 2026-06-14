module data_mem(
    input wire clk,
    input wire rst,
    input wire we,
    input wire [31:0] alu_result,
    input wire [31:0] write_data,
    output reg [31:0] read_data
);
    integer i;
    reg [31:0] data_memory [0:255];
    initial begin
        for ( i= 0; i < 256; i = i + 1) begin
            data_memory[i] = 32'h0000_0000;
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            read_data<=32'h0000_0000;
        end else if (we) begin
            data_memory[alu_result[9:2]] <= write_data;
        end 
    end
    always @(*)begin
            if (rst)begin
              read_data=32'h0000_0000;
            end
            else begin
                read_data=data_memory[alu_result[9:2]];
            end
    end
endmodule