# ============================================================================
# test_jump.s — JAL / JALR instruction tests
# Tests: jal forward/backward, jalr, return address correctness
# Error codes: 501–506
# ============================================================================

    # ----------------------------------------------------------------
    # Test 1: jal forward — verify jump + flush of 2 delay slots
    # ----------------------------------------------------------------
    addi x5, x0, 77
    jal  x0, jal1_target        # jump, discard return address (rd=x0)
    addi x5, x0, 0              # POISON 1 (should be flushed)
    addi x5, x0, 0              # POISON 2 (should be flushed)
jal1_target:
    addi x6, x0, 77
    bne  x5, x6, fail_501       # x5 should still be 77 (poisons flushed)

    # ----------------------------------------------------------------
    # Test 2: jal forward — save return address, verify non-zero
    # ----------------------------------------------------------------
    jal  x1, jal2_target        # x1 = return address (PC+4)
    addi x5, x0, 0              # POISON (flushed)
    addi x5, x0, 0              # POISON (flushed)
jal2_target:
    bne  x1, x0, jal2_ra_ok     # ra should be non-zero
    addi x28, x0, 502
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_502
jal2_ra_ok:

    # ----------------------------------------------------------------
    # Test 3: jal + jalr — call and return
    #    callee sets x5=33, returns via jalr. Caller verifies x5.
    # ----------------------------------------------------------------
    addi x5, x0, 0
    jal  x1, callee             # call: x1 = return addr (next instr)
    # Return here after jalr
    addi x6, x0, 33
    bne  x5, x6, fail_503       # callee should have set x5 = 33
    jal  x0, test4              # skip over callee body

callee:
    addi x5, x0, 33
    jalr x0, x1, 0              # return (rd=x0, jump to ra)

test4:
    # ----------------------------------------------------------------
    # Test 4: jalr with non-zero immediate offset
    #    Use auipc to get PC, then jalr with offset to reach a target
    # ----------------------------------------------------------------
    addi x5, x0, 88
    # Capture the address of 'jalr4_anchor' using jal
    jal  x2, jalr4_anchor
jalr4_anchor:
    # x2 = address of jalr4_anchor. Target is jalr4_target.
    # Offset from jalr4_anchor to jalr4_target is known (count instrs * 4)
    # jalr4_anchor at offset 0, jalr4_target is 2 instrs later = 8 bytes
    addi x2, x2, 8              # x2 = address of jalr4_target
    jalr x0, x2, 0              # jump to jalr4_target via jalr
    addi x5, x0, 0              # POISON 1 (flushed)
    addi x5, x0, 0              # POISON 2 (flushed)
jalr4_target:
    addi x6, x0, 88
    bne  x5, x6, fail_504       # x5 should still be 88

    # ----------------------------------------------------------------
    # Test 5: backward jump via jal
    # ----------------------------------------------------------------
    addi x1, x0, 0              # counter = 0
    addi x2, x0, 3              # limit = 3
jump5_loop:
    addi x1, x1, 1              # counter++
    bne  x1, x2, jump5_loop     # backward until counter == 3
    addi x3, x0, 3
    bne  x1, x3, fail_505       # x1 should be 3

    # ----------------------------------------------------------------
    # Test 6: jal with rd=x1, then jalr x0, x1, 4 to skip 1 instr
    # ----------------------------------------------------------------
    addi x5, x0, 0
    jal  x1, jal6_mid           # save return addr in x1, jump to jal6_mid
    addi x5, x0, 0              # POISON (flushed)
jal6_mid:
    addi x1, x1, 4              # x1 = addr of the instruction AFTER the next
    jalr x0, x1, 0              # jump to x1, skipping "addi x5, x0, 99"
    addi x5, x0, 99             # should be SKIPPED by jalr
    addi x6, x0, 0
    bne  x5, x6, fail_506       # x5 should still be 0 (never set to 99)

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
fail_501:
    addi x28, x0, 501
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_501

fail_502:
    addi x28, x0, 502
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_502

fail_503:
    addi x28, x0, 503
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_503

fail_504:
    addi x28, x0, 504
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_504

fail_505:
    addi x28, x0, 505
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_505

fail_506:
    addi x28, x0, 506
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_506
