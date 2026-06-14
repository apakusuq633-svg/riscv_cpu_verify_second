// ============================================================================
// RISC-V WB (写回) 阶段 — 组合逻辑
// 选择写入寄存器堆的数据: 内存 / ALU 结果 / PC+4 (跳转返回地址)
// ============================================================================
module WB(
    input wire [31:0] alu_result,
    input wire [31:0] read_data,
    input wire [31:0] pc_plus_4,
    input wire MemtoReg,
    input wire Jump,
    output wire [31:0] write_data
);
    // Jump 优先: JAL/JALR 写回 PC+4 (返回地址)
    assign write_data = Jump   ? pc_plus_4  :
                        MemtoReg ? read_data   :
                                   alu_result;

endmodule
