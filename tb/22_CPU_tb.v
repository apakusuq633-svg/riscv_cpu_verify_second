//          ./tools/assemble.sh tests/asm/program.s
//          iverilog -g2012 -Wall -o sim/cpu_tb.vvp tb/22_CPU_tb.v rtl/*.v
//          vvp sim/cpu_tb.vvp +hexfile=tests/hex/program.hex +nocheck
// ============================================================================
// RISC-V RV32I 5-Stage Pipeline CPU Testbench
// ============================================================================
module CPU_tb;
    reg clk;
    reg rst;
    initial begin
        $dumpfile("sim/cpu.vcd");
        $dumpvars(0, CPU_tb);
    end

    // 实例化顶层 CPU
    CPU_top cpu(
        .clk(clk),
        .rst(rst)
    );

    // 时钟生成: 10ns 周期 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // 复位
        rst = 1;
        #15;
        rst = 0;

        // 多跑一会儿，确保流水线完全排空
        #800;
            // ================================================================
            $display("--- Register File ---");
            $display("  x0=%08h  x1(ra)=%08h  x2(sp)=%08h  x3(gp)=%08h",
                     cpu.reg_file.register_file[0],
                     cpu.reg_file.register_file[1],
                     cpu.reg_file.register_file[2],
                     cpu.reg_file.register_file[3]);
            $display("  x4(tp)=%08h  x5(t0)=%08h  x6(t1)=%08h  x7(t2)=%08h",
                     cpu.reg_file.register_file[4],
                     cpu.reg_file.register_file[5],
                     cpu.reg_file.register_file[6],
                     cpu.reg_file.register_file[7]);
            $display("  x8(s0)=%08h  x9(s1)=%08h  x10(a0)=%08h  x11(a1)=%08h",
                     cpu.reg_file.register_file[8],
                     cpu.reg_file.register_file[9],
                     cpu.reg_file.register_file[10],
                     cpu.reg_file.register_file[11]);
            $display("  x12(s2)=%08h  x13(s3)=%08h  x14(s4)=%08h  x15(s5)=%08h",
                     cpu.reg_file.register_file[12],
                     cpu.reg_file.register_file[13],
                     cpu.reg_file.register_file[14],
                     cpu.reg_file.register_file[15]);
            $display("  x16(s6)=%08h  x17(s7)=%08h  x18(s8)=%08h  x19(s9)=%08h",
                     cpu.reg_file.register_file[16],
                     cpu.reg_file.register_file[17],
                        cpu.reg_file.register_file[18],
                        cpu.reg_file.register_file[19]);
            $display("  x20(s10)=%08h  x21(s11)=%08h  x22(t3)=%08h  x23(t4)=%08h",
                        cpu.reg_file.register_file[20],
                        cpu.reg_file.register_file[21],
                        cpu.reg_file.register_file[22],
                        cpu.reg_file.register_file[23]);
            $display("  x24(t5)=%08h  x25(t6)=%08h  x26(s12)=%08h  x27(s13)=%08h",
                        cpu.reg_file.register_file[24],
                        cpu.reg_file.register_file[25],
                        cpu.reg_file.register_file[26],
                        cpu.reg_file.register_file[27]);
            $display("  x28(s14)=%08h  x29(s15)=%08h  x30(s16)=%08h  x31(s17)=%08h",
                        cpu.reg_file.register_file[28],     
                        cpu.reg_file.register_file[29],
                        cpu.reg_file.register_file[30],
                        cpu.reg_file.register_file[31]);

        $display("\n========== Simulation Done ==========");
        $display("Check sim/cpu.vcd waveform for verification.");
        $finish;
    end

    // ========================================================================
    // 仿真开始提示
    // ========================================================================
    initial begin
        $display("======================================================================");
        $display("  RISC-V RV32I 5-Stage Pipeline CPU Simulation");
        $display("  All encoded signals printed cycle by cycle");
        $display("======================================================================");
    end

    // ========================================================================
    // 流水线全信号追踪 — 每个时钟周期打印所有编码信号
    // ========================================================================


            /*
            // ================================================================
            // 周期标题
            // ================================================================
            $display("");
            $display("======================================================================");
            $display("  Cycle %3d, Time: %5t", cycle, $time);
            $display("======================================================================");

            // ================================================================
            // IF Stage
            // ================================================================
            $display("--- IF Stage ---");
            $display("  PC=%08h  NextPC=%08h  Inst_IF=%08h",
                     cpu.PC, cpu.next_pc, cpu.instruction_IF);

            // ================================================================
            // ID Stage (Decode)
            // ================================================================
            $display("--- ID Stage (Decode) ---");
            $display("  PC_ID=%08h  Inst_ID=%08h  Stall=%b",
                     cpu.PC_ID, cpu.instruction_ID, cpu.stall);
            $display("  opcode=%02h  rs1=x%02d  rs2=x%02d  rd=x%02d  funct3=%03b  funct7=%07b",
                     cpu.opcode, cpu.rs1, cpu.rs2, cpu.rd,
                     cpu.funct3, cpu.funct7);
            $display("  ImmSrc=%03b  imm_ext=%08h",
                     cpu.ImmSrcD, cpu.imm_extended);
            $display("  RD1=%08h  RD2=%08h",
                     cpu.RD1, cpu.RD2);
            $display("  Ctrl: RegW=%b Mem2R=%b MemW=%b MemR=%b ALUOp=%02b ALUSrc=%b Branch=%b Jump=%b LUI=%b AUIPC=%b JALR=%b",
                     cpu.RegWriteD, cpu.MemtoRegD, cpu.MemWriteD, cpu.MemReadD,
                     cpu.ALUOpD, cpu.ALUSrcD,
                     cpu.BranchD, cpu.JumpD,
                     cpu.LUID, cpu.AUIPCD, cpu.JALRD);

            // ================================================================
            // Hazard / Forwarding Unit
            // ================================================================
            $display("--- Hazard / Forwarding ---");
            $display("  Stall=%b  Flush=%b  ForwardAE=%02b  ForwardBE=%02b",
                     cpu.stall, cpu.flush_ID_EX, cpu.ForwardAE, cpu.ForwardBE);

            // ================================================================
            // EX Stage
            // ================================================================
            $display("--- EX Stage ---");
            $display("  PC_EX=%08h  ALUCtrl=%04b",
                     cpu.PC_EX, cpu.ALUControl);
            $display("  rs1=x%02d  rs2=x%02d  rd=x%02d  funct3=%03b  funct7=%07b",
                     cpu.rs1_EX, cpu.rs2_EX, cpu.rd_EX,
                     cpu.funct3_EX, cpu.funct7_EX);
            $display("  RD1=%08h  RD2=%08h  imm=%08h  StoreData=%08h",
                     cpu.RD1_EX, cpu.RD2_EX, cpu.imm_EX, cpu.store_data_EX);
            $display("  Ctrl: RegW=%b Mem2R=%b MemW=%b MemR=%b ALUOp=%02b ALUSrc=%b Branch=%b Jump=%b LUI=%b AUIPC=%b JALR=%b",
                     cpu.RegWriteE, cpu.MemtoRegE, cpu.MemWriteE, cpu.MemReadE,
                     cpu.ALUOpE, cpu.ALUSrcE,
                     cpu.BranchE, cpu.JumpE,
                     cpu.LUIE, cpu.AUIPCE, cpu.JALRE);
            $display("  ALUResult=%08h  zero=%b",
                     cpu.ALU_result_EX, cpu.zero_flag_EX);
            $display("  br_tgt=%08h  jmp_tgt=%08h  pc+4=%08h",
                     cpu.branch_target_EX, cpu.jump_target_EX, cpu.pc_plus_4_EX);

            // ================================================================
            // MEM Stage
            // ================================================================
            $display("--- MEM Stage ---");
            $display("  ALUResult=%08h  RD2=%08h  rd=x%02d",
                     cpu.ALU_result_MEM, cpu.RD2_MEM, cpu.rd_MEM);
            $display("  Ctrl: RegW=%b Mem2R=%b MemW=%b MemR=%b Branch=%b Jump=%b JALR=%b",
                     cpu.RegWriteM, cpu.MemtoRegM, cpu.MemWriteM, cpu.MemReadM,
                     cpu.BranchM, cpu.JumpM, cpu.JALRM);
            $display("  br_tgt=%08h  jmp_tgt=%08h  pc+4=%08h  zero=%b  funct3=%03b",
                     cpu.branch_target_MEM, cpu.jump_target_MEM, cpu.pc_plus_4_MEM,
                     cpu.zero_flag_MEM, cpu.funct3_MEM);
            $display("  BrTaken=%b  NextPC=%08h  ReadData=%08h",
                     cpu.branch_taken, cpu.branch_next_pc, cpu.read_data_MEM);

            // ================================================================
            // WB Stage
            // ================================================================
            $display("--- WB Stage ---");
            $display("  Ctrl: RegW=%b Mem2R=%b Jump=%b",
                     cpu.RegWriteW, cpu.MemtoRegW, cpu.JumpW);
            $display("  ALUResult=%08h  ReadData=%08h  pc+4=%08h  rd=x%02d",
                     cpu.ALU_result_WB, cpu.read_data_WB, cpu.pc_plus_4_WB, cpu.rd_WB);
            $display("  WriteData=%08h",
                     cpu.write_data);
*/
            // ================================================================
            // Register File Values (x0 - x7)
            // ================================================================
endmodule
