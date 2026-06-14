// ============================================================================
// ID/EX 流水线寄存器 (RISC-V)
// ============================================================================
module ID_EX(
    input wire clk,
    input wire rst,
    input wire flush,
    // ---- ID 阶段控制信号 ----
    input wire RegWriteD,
    input wire MemtoRegD,
    input wire MemWriteD,
    input wire MemReadD,
    input wire [1:0] ALUOpD,
    input wire ALUSrcD,
    input wire BranchD,
    input wire JumpD,
    input wire [2:0] ImmSrcD,
    input wire LUID,
    input wire AUIPCD,
    input wire JALRD,
    // ---- ID 阶段数据信号 ----
    input wire [31:0] PC_in,
    input wire [31:0] RD1,
    input wire [31:0] RD2,
    input wire [31:0] sign_ext_imm,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [2:0] funct3,
    input wire [6:0] funct7,

    // ---- EX 阶段控制信号 ----
    output reg RegWriteE,
    output reg MemtoRegE,
    output reg MemWriteE,
    output reg MemReadE,
    output reg [1:0] ALUOpE,
    output reg ALUSrcE,
    output reg BranchE,
    output reg JumpE,
    output reg [2:0] ImmSrcE,
    output reg LUIE,
    output reg AUIPCE,
    output reg JALRE,
    // ---- EX 阶段数据信号 ----
    output reg [31:0] PC_out,
    output reg [31:0] RD1_out,
    output reg [31:0] RD2_out,
    output reg [31:0] imm_out,
    output reg [4:0] rs1_out,
    output reg [4:0] rs2_out,
    output reg [4:0] rd_out,
    output reg [2:0] funct3_out,
    output reg [6:0] funct7_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteE  <= 1'b0;
            MemtoRegE  <= 1'b0;
            MemWriteE  <= 1'b0;
            MemReadE   <= 1'b0;
            ALUOpE     <= 2'b00;
            ALUSrcE    <= 1'b0;
            BranchE    <= 1'b0;
            JumpE      <= 1'b0;
            ImmSrcE    <= 3'b000;
            LUIE       <= 1'b0;
            AUIPCE     <= 1'b0;
            JALRE      <= 1'b0;
            PC_out     <= 32'h0000_0000;
            RD1_out    <= 32'h0000_0000;
            RD2_out    <= 32'h0000_0000;
            imm_out    <= 32'h0000_0000;
            rs1_out    <= 5'b00000;
            rs2_out    <= 5'b00000;
            rd_out     <= 5'b00000;
            funct3_out <= 3'b000;
            funct7_out <= 7'b0000000;
        end else if (flush) begin
            // 冲突时清空: 插入 NOP (控制信号清零)
            RegWriteE  <= 1'b0;
            MemtoRegE  <= 1'b0;
            MemWriteE  <= 1'b0;
            MemReadE   <= 1'b0;
            ALUOpE     <= 2'b00;
            ALUSrcE    <= 1'b0;
            BranchE    <= 1'b0;
            JumpE      <= 1'b0;
            ImmSrcE    <= 3'b000;
            LUIE       <= 1'b0;
            AUIPCE     <= 1'b0;
            JALRE      <= 1'b0;
        end else begin
            RegWriteE  <= RegWriteD;
            MemtoRegE  <= MemtoRegD;
            MemWriteE  <= MemWriteD;
            MemReadE   <= MemReadD;
            ALUOpE     <= ALUOpD;
            ALUSrcE    <= ALUSrcD;
            BranchE    <= BranchD;
            JumpE      <= JumpD;
            ImmSrcE    <= ImmSrcD;
            LUIE       <= LUID;
            AUIPCE     <= AUIPCD;
            JALRE      <= JALRD;
            PC_out     <= PC_in;
            RD1_out    <= RD1;
            RD2_out    <= RD2;
            imm_out    <= sign_ext_imm;
            rs1_out    <= rs1;
            rs2_out    <= rs2;
            rd_out     <= rd;
            funct3_out <= funct3;
            funct7_out <= funct7;
        end
    end
endmodule
