// ============================================================================
// EX/MEM 流水线寄存器 (RISC-V)
// ============================================================================
module EX_MEM(
    input wire clk,
    input wire rst,
    // ---- EX 阶段控制信号 ----
    input wire RegWriteE,
    input wire MemtoRegE,
    input wire MemWriteE,
    input wire MemReadE,
    input wire BranchE,
    input wire JumpE,
    input wire JALRE,
    // ---- EX 阶段数据信号 ----
    input wire [31:0] ALU_result,
    input wire [31:0] RD2_E,
    input wire [4:0] rd_E,
    input wire [31:0] branch_target,
    input wire [31:0] jump_target,
    input wire [31:0] pc_plus_4,
    input wire zero_flag,
    input wire [2:0] funct3,

    // ---- MEM 阶段控制信号 ----
    output reg RegWriteM,
    output reg MemtoRegM,
    output reg MemWriteM,
    output reg MemReadM,
    output reg BranchM,
    output reg JumpM,
    output reg JALRM,
    // ---- MEM 阶段数据信号 ----
    output reg [31:0] ALU_result_out,
    output reg [31:0] RD2_out,
    output reg [4:0] rd_out,
    output reg [31:0] branch_target_out,
    output reg [31:0] jump_target_out,
    output reg [31:0] pc_plus_4_out,
    output reg zero_flag_out,
    output reg [2:0] funct3_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteM         <= 1'b0;
            MemtoRegM         <= 1'b0;
            MemWriteM         <= 1'b0;
            MemReadM          <= 1'b0;
            BranchM           <= 1'b0;
            JumpM             <= 1'b0;
            JALRM             <= 1'b0;
            ALU_result_out    <= 32'h0000_0000;
            RD2_out           <= 32'h0000_0000;
            rd_out            <= 5'b00000;
            branch_target_out <= 32'h0000_0000;
            jump_target_out   <= 32'h0000_0000;
            pc_plus_4_out     <= 32'h0000_0000;
            zero_flag_out      <= 1'b0;
            funct3_out        <= 3'b000;
       
       
        end else begin
            RegWriteM         <= RegWriteE;
            MemtoRegM         <= MemtoRegE;
            MemWriteM         <= MemWriteE;
            MemReadM          <= MemReadE;
            BranchM           <= BranchE;
            JumpM             <= JumpE;
            JALRM             <= JALRE;
            ALU_result_out    <= ALU_result;
            RD2_out           <= RD2_E;
            rd_out            <= rd_E;
            branch_target_out <= branch_target;
            jump_target_out   <= jump_target;
            pc_plus_4_out     <= pc_plus_4;
            zero_flag_out      <= zero_flag;
            funct3_out        <= funct3;
        end
    end
endmodule
