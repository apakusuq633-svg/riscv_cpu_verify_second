# ============================================================================
# test_load_store.s — Memory instruction tests
# Tests: sw, lw, sb, lb, lbu, sh, lh, lhu
# Tests various offsets and sign/zero extension.
# Error codes: 401–412
# All data stored in low memory (0x00–0x30), away from tohost (0x3F0).
# ============================================================================

    # ----------------------------------------------------------------
    # Test 1: sw + lw — basic store/load word
    # ----------------------------------------------------------------
    addi x1, x0, 0xDEADBEEF
    sw   x1, 0x00(x0)           # mem[0x00] = 0xDEADBEEF
    lw   x3, 0x00(x0)
    addi x4, x0, 0x0            # can't load 32-bit imm directly
    # Compare: x3 should be 0xDEADBEEF
    # Use xor to check equality (xor of equal values = 0)
    # But we can't easily load 0xDEADBEEF as immediate...
    # Actually, let me use a simpler pattern:
    addi x1, x0, 0x123          # use a value that fits in 12-bit
    slli x1, x1, 12             # x1 = 0x00123000
    addi x1, x1, 0x456          # x1 = 0x00123456
    sw   x1, 0x00(x0)
    lw   x3, 0x00(x0)
    # Compare by sub and check zero
    sub  x5, x3, x1
    bne  x5, x0, fail_401

    # ----------------------------------------------------------------
    # Test 2: sw + lw — different offset
    # ----------------------------------------------------------------
    addi x1, x0, 42
    sw   x1, 0x10(x0)           # mem[0x10] = 42
    lw   x3, 0x10(x0)
    addi x4, x0, 42
    bne  x3, x4, fail_402

    # ----------------------------------------------------------------
    # Test 3: sw + lw — offset with non-zero base
    # ----------------------------------------------------------------
    addi x1, x0, 99
    addi x2, x0, 0x08
    sw   x1, 0x04(x2)           # mem[0x0C] = 99
    lw   x3, 0x04(x2)
    addi x4, x0, 99
    bne  x3, x4, fail_403

    # ----------------------------------------------------------------
    # Test 4: sb + lb — byte store/load (sign-extended)
    #    store 0xFF (-1 as byte), load back → should be 0xFFFFFFFF
    # ----------------------------------------------------------------
    addi x1, x0, -1             # x1 = 0xFFFFFFFF
    sb   x1, 0x14(x0)           # mem[0x14] = 0xFF
    lb   x3, 0x14(x0)           # x3 = sign-extended = 0xFFFFFFFF = -1
    addi x4, x0, -1
    bne  x3, x4, fail_404

    # ----------------------------------------------------------------
    # Test 5: sb + lb — positive byte
    # ----------------------------------------------------------------
    addi x1, x0, 0x7F           # x1 = 127
    sb   x1, 0x15(x0)           # mem[0x15] = 0x7F
    lb   x3, 0x15(x0)           # x3 = 127 (positive, sign-extended to 0x0000007F)
    addi x4, x0, 127
    bne  x3, x4, fail_405

    # ----------------------------------------------------------------
    # Test 6: sb + lbu — byte load unsigned (zero-extended)
    # ----------------------------------------------------------------
    addi x1, x0, -1             # x1 = 0xFFFFFFFF
    sb   x1, 0x16(x0)           # mem[0x16] = 0xFF
    lbu  x3, 0x16(x0)           # x3 = 0x000000FF = 255
    addi x4, x0, 255
    bne  x3, x4, fail_406

    # ----------------------------------------------------------------
    # Test 7: sh + lh — halfword store/load (sign-extended)
    #    store 0xFFFF8000 as halfword (= 0x8000 = -32768)
    # ----------------------------------------------------------------
    addi x1, x0, -1
    slli x1, x1, 15             # x1 = 0xFFFF8000
    addi x2, x0, 0
    addi x2, x2, 1
    slli x2, x2, 15             # x2 = 0x00008000
    sub  x1, x0, x2             # x1 = 0xFFFF8000 = -32768
    sh   x1, 0x18(x0)           # mem[0x18:0x19] = 0x8000
    lh   x3, 0x18(x0)           # x3 = sign-extended = 0xFFFF8000
    # Check with sub
    addi x4, x0, 0
    sub  x4, x4, x2             # x4 = -32768 = 0xFFFF8000
    sub  x5, x3, x4
    bne  x5, x0, fail_407

    # ----------------------------------------------------------------
    # Test 8: sh + lh — positive halfword
    # ----------------------------------------------------------------
    addi x1, x0, 0x7FFF         # max positive 16-bit signed
    sh   x1, 0x1A(x0)
    lh   x3, 0x1A(x0)
    addi x4, x0, 0x7FFF
    bne  x3, x4, fail_408

    # ----------------------------------------------------------------
    # Test 9: sh + lhu — halfword load unsigned
    # ----------------------------------------------------------------
    addi x1, x0, -1
    slli x1, x1, 15             # x1 = 0xFFFF8000
    addi x2, x0, 0
    addi x2, x2, 1
    slli x2, x2, 15
    sub  x1, x0, x2             # x1 = 0xFFFF8000
    sh   x1, 0x1C(x0)           # store lower 16 bits = 0x8000
    lhu  x3, 0x1C(x0)           # x3 = 0x00008000 = 32768
    addi x4, x0, 0
    addi x4, x4, 1
    slli x4, x4, 15             # x4 = 0x00008000 = 32768
    bne  x3, x4, fail_409

    # ----------------------------------------------------------------
    # Test 10: multiple stores, verify they don't interfere
    # ----------------------------------------------------------------
    addi x1, x0, 111
    sw   x1, 0x20(x0)
    addi x1, x0, 222
    sw   x1, 0x24(x0)
    lw   x3, 0x20(x0)
    addi x4, x0, 111
    bne  x3, x4, fail_410
    lw   x3, 0x24(x0)
    addi x4, x0, 222
    bne  x3, x4, fail_411

    # ----------------------------------------------------------------
    # Test 11: load with offset using register base
    # ----------------------------------------------------------------
    addi x2, x0, 0x20
    lw   x3, 0x00(x2)           # mem[0x20] = 111 (from previous test)
    addi x4, x0, 111
    bne  x3, x4, fail_412

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
fail_401:
    addi x28, x0, 401
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_401

fail_402:
    addi x28, x0, 402
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_402

fail_403:
    addi x28, x0, 403
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_403

fail_404:
    addi x28, x0, 404
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_404

fail_405:
    addi x28, x0, 405
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_405

fail_406:
    addi x28, x0, 406
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_406

fail_407:
    addi x28, x0, 407
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_407

fail_408:
    addi x28, x0, 408
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_408

fail_409:
    addi x28, x0, 409
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_409

fail_410:
    addi x28, x0, 410
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_410

fail_411:
    addi x28, x0, 411
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_411

fail_412:
    addi x28, x0, 412
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_412
