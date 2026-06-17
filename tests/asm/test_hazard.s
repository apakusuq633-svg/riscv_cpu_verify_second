# ============================================================================
# test_hazard.s — Pipeline hazard tests
# Tests: load-use stall, forwarding (MEM vs WB priority), back-to-back deps
# Error codes: 601–608
# ============================================================================

    # ----------------------------------------------------------------
    # Test 1: load-use hazard — lw followed immediately by consumer
    #    Pipeline must stall 1 cycle for load data to arrive.
    # ----------------------------------------------------------------
    addi x1, x0, 123
    sw   x1, 0x30(x0)           # mem[0x30] = 123
    lw   x3, 0x30(x0)           # load 123 into x3
    add  x4, x3, x0             # consumer: x4 = x3 + 0 = 123 (must stall)
    addi x5, x0, 123
    bne  x4, x5, fail_601       # x4 should be 123

    # ----------------------------------------------------------------
    # Test 2: load-use with different register (no stall needed)
    # ----------------------------------------------------------------
    addi x1, x0, 200
    sw   x1, 0x34(x0)
    lw   x6, 0x34(x0)           # x6 = 200
    addi x7, x0, 55             # independent instruction (no stall needed)
    add  x8, x6, x0             # consumer: x8 = 200
    addi x9, x0, 200
    bne  x8, x9, fail_602
    # Also verify x7 wasn't affected
    addi x9, x0, 55
    bne  x7, x9, fail_603

    # ----------------------------------------------------------------
    # Test 3: back-to-back dependencies — forwarding handles it
    #    addi → add → sub — all forwarded, no stalls
    # ----------------------------------------------------------------
    addi x1, x0, 10
    add  x2, x1, x0             # x2 = 10 (forwarded from EX_MEM)
    sub  x3, x2, x1             # x3 = 0 (x2 forwarded, x1 from regfile)
    bne  x3, x0, fail_604

    # ----------------------------------------------------------------
    # Test 4: three-instruction dependency chain
    # ----------------------------------------------------------------
    addi x1, x0, 5
    addi x1, x1, 10             # x1 = 15 (forwarded)
    addi x1, x1, 20             # x1 = 35 (forwarded)
    addi x2, x0, 35
    bne  x1, x2, fail_605

    # ----------------------------------------------------------------
    # Test 5: MEM forwarding priority over WB forwarding
    #    Instruction A produces x5 (in MEM), instruction B produces x5 (in WB)
    #    Consumer should get MEM value (newer)
    # ----------------------------------------------------------------
    addi x5, x0, 100            # A: x5 = 100 (will reach MEM)
    addi x5, x0, 200            # B: x5 = 200 (will reach EX)
    # Now A is in MEM (RegWriteM=1, rd_M=x5, ALU_result=100)
    # B is in EX (producing x5=200)
    # Wait, actually the pipeline timing means:
    # Cycle N:   A in EX, B in ID
    # Cycle N+1: A in MEM, B in EX
    # Consumer C reads x5 in ID at cycle N+1, enters EX at N+2
    # At N+2: A is in WB (RegWriteW=1, value=100)
    #         B is in MEM (RegWriteM=1, value=200)
    # Forwarding: MEM (200) has priority over WB (100) → consumer gets 200 ✓
    # But wait, consumer C is what? Let me structure this test more carefully.
    addi x1, x5, 0              # C: x1 = x5 (should get 200 if forwarding works)
    addi x2, x0, 200
    bne  x1, x2, fail_606

    # ----------------------------------------------------------------
    # Test 6: WB forwarding (MEM not available, fall back to WB)
    # ----------------------------------------------------------------
    addi x5, x0, 77             # D: x5 = 77
    nop                         # gap — D goes to MEM, then WB
    nop                         # gap — D goes to WB
    addi x6, x5, 0              # E: x6 = x5 (must forward from WB)
    addi x2, x0, 77
    bne  x6, x2, fail_607

    # ----------------------------------------------------------------
    # Test 7: store data forwarding
    #    sw uses a register value that was just produced
    # ----------------------------------------------------------------
    addi x10, x0, 0xAB
    addi x10, x10, 0x100        # x10 = 0x1AB (forwarded to EX for ALU)
    addi x11, x0, 0x30
    sw   x10, 0x38(x0)          # store 0x1AB to mem[0x38]
    lw   x12, 0x38(x0)          # load back
    addi x13, x0, 0x1AB
    bne  x12, x13, fail_608     # should be 0x1AB

    # ----------------------------------------------------------------
    # Test 8: consecutive stores — verify data correctness
    # ----------------------------------------------------------------
    addi x10, x0, 111
    addi x11, x0, 222
    sw   x10, 0x40(x0)
    sw   x11, 0x44(x0)
    lw   x12, 0x40(x0)
    lw   x13, 0x44(x0)
    addi x14, x0, 111
    addi x15, x0, 222
    bne  x12, x14, fail_609
    bne  x13, x15, fail_610

    # ----------------------------------------------------------------
    # All tests passed
    # ----------------------------------------------------------------
pass:
    addi x28, x0, 1
    sw   x28, 0x3F0(x0)
    beq  x0, x0, pass

    # ----------------------------------------------------------------
    # Fail handlers
    # ----------------------------------------------------------------
fail_601:
    addi x28, x0, 601
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_601

fail_602:
    addi x28, x0, 602
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_602

fail_603:
    addi x28, x0, 603
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_603

fail_604:
    addi x28, x0, 604
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_604

fail_605:
    addi x28, x0, 605
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_605

fail_606:
    addi x28, x0, 606
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_606

fail_607:
    addi x28, x0, 607
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_607

fail_608:
    addi x28, x0, 608
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_608

fail_609:
    addi x28, x0, 609
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_609

fail_610:
    addi x28, x0, 610
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_610
