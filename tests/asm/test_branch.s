# ============================================================================
# test_branch.s — Branch instruction tests
# Tests: beq, bne, blt, bge, bltu, bgeu (taken + not-taken each)
# Also verifies that delay-slot instructions are properly flushed.
# Error codes: 301–318
# ============================================================================

    # ----------------------------------------------------------------
    # Test 1: beq — equal → taken.  Verify 2 delay-slot instrs flushed.
    # ----------------------------------------------------------------
    addi x1, x0, 5
    addi x2, x0, 5
    addi x5, x0, 99              # safe value — should survive
    beq  x1, x2, beq_taken_ok    # taken (x1 == x2)
    addi x5, x0, 0               # POISON 1: flush expected
    addi x5, x0, 0               # POISON 2: flush expected
beq_taken_ok:
    addi x6, x0, 99
    bne  x5, x6, fail_301

    # ----------------------------------------------------------------
    # Test 2: beq — not equal → not taken.  Delay-slot instrs execute.
    # ----------------------------------------------------------------
    addi x1, x0, 10
    addi x2, x0, 20              # x1 != x2
    addi x5, x0, 0
    beq  x1, x2, beq_not_skip    # NOT taken
    addi x5, x0, 1               # SHOULD execute
    addi x5, x5, 2               # SHOULD execute → x5 = 3
beq_not_skip:
    addi x6, x0, 3               # expect x5 = 3 (both instrs executed)
    bne  x5, x6, fail_302

    # ----------------------------------------------------------------
    # Test 3: bne — not equal → taken
    # ----------------------------------------------------------------
    addi x1, x0, 3
    addi x2, x0, 7               # x1 != x2
    addi x5, x0, 88
    bne  x1, x2, bne_taken_ok    # taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bne_taken_ok:
    addi x6, x0, 88
    bne  x5, x6, fail_303

    # ----------------------------------------------------------------
    # Test 4: bne — equal → not taken
    # ----------------------------------------------------------------
    addi x1, x0, 42
    addi x2, x0, 42              # x1 == x2
    addi x5, x0, 0
    bne  x1, x2, bne_not_skip    # NOT taken
    addi x5, x0, 4               # SHOULD execute
    addi x5, x5, 5               # SHOULD execute → x5 = 9
bne_not_skip:
    addi x6, x0, 9
    bne  x5, x6, fail_304

    # ----------------------------------------------------------------
    # Test 5: blt — less than (signed) → taken
    # ----------------------------------------------------------------
    addi x1, x0, -5
    addi x2, x0, 10              # -5 < 10 (signed)
    addi x5, x0, 77
    blt  x1, x2, blt_taken_ok    # taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
blt_taken_ok:
    addi x6, x0, 77
    bne  x5, x6, fail_305

    # ----------------------------------------------------------------
    # Test 6: blt — not less than → not taken
    # ----------------------------------------------------------------
    addi x1, x0, 10
    addi x2, x0, -5              # 10 > -5, not less
    addi x5, x0, 0
    blt  x1, x2, blt_not_skip    # NOT taken
    addi x5, x0, 6               # SHOULD execute
    addi x5, x5, 6               # SHOULD execute → x5 = 12
blt_not_skip:
    addi x6, x0, 12
    bne  x5, x6, fail_306

    # ----------------------------------------------------------------
    # Test 7: bge — greater or equal → taken (greater case)
    # ----------------------------------------------------------------
    addi x1, x0, 20
    addi x2, x0, 5               # 20 >= 5
    addi x5, x0, 66
    bge  x1, x2, bge_taken_ok    # taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bge_taken_ok:
    addi x6, x0, 66
    bne  x5, x6, fail_307

    # ----------------------------------------------------------------
    # Test 8: bge — equal → taken
    # ----------------------------------------------------------------
    addi x1, x0, 7
    addi x2, x0, 7               # 7 >= 7
    addi x5, x0, 55
    bge  x1, x2, bge_eq_ok       # taken (equal counts as >=)
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bge_eq_ok:
    addi x6, x0, 55
    bne  x5, x6, fail_308

    # ----------------------------------------------------------------
    # Test 9: bge — less than → not taken
    # ----------------------------------------------------------------
    addi x1, x0, 3
    addi x2, x0, 10              # 3 < 10, not >=
    addi x5, x0, 0
    bge  x1, x2, bge_not_skip    # NOT taken
    addi x5, x0, 7               # SHOULD execute
    addi x5, x5, 7               # SHOULD execute → x5 = 14
bge_not_skip:
    addi x6, x0, 14
    bne  x5, x6, fail_309

    # ----------------------------------------------------------------
    # Test 10: bltu — unsigned less → taken
    #    -5 signed = 0xFFFFFFFB unsigned = 4294967291
    #    10 unsigned = 10
    #    So 10 < -5 (unsigned) is true
    # ----------------------------------------------------------------
    addi x1, x0, 10
    addi x2, x0, -5              # x2 = 0xFFFFFFFB (huge unsigned)
    addi x5, x0, 44
    bltu x1, x2, bltu_taken_ok   # 10 < 0xFFFFFFFB → taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bltu_taken_ok:
    addi x6, x0, 44
    bne  x5, x6, fail_310

    # ----------------------------------------------------------------
    # Test 11: bltu — not less → not taken
    # ----------------------------------------------------------------
    addi x1, x0, -5              # x1 = 0xFFFFFFFB (huge unsigned)
    addi x2, x0, 10              # 0xFFFFFFFB > 10, so not less
    addi x5, x0, 0
    bltu x1, x2, bltu_not_skip   # NOT taken
    addi x5, x0, 8               # SHOULD execute
    addi x5, x5, 8               # SHOULD execute → x5 = 16
bltu_not_skip:
    addi x6, x0, 16
    bne  x5, x6, fail_311

    # ----------------------------------------------------------------
    # Test 12: bgeu — unsigned greater or equal → taken
    # ----------------------------------------------------------------
    addi x1, x0, -5              # x1 = 0xFFFFFFFB (huge unsigned)
    addi x2, x0, 10              # 0xFFFFFFFB >= 10 → taken
    addi x5, x0, 33
    bgeu x1, x2, bgeu_taken_ok   # taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bgeu_taken_ok:
    addi x6, x0, 33
    bne  x5, x6, fail_312

    # ----------------------------------------------------------------
    # Test 13: bgeu — equal → taken
    # ----------------------------------------------------------------
    addi x1, x0, 100
    addi x2, x0, 100
    addi x5, x0, 22
    bgeu x1, x2, bgeu_eq_ok      # 100 >= 100 → taken
    addi x5, x0, 0               # POISON 1
    addi x5, x0, 0               # POISON 2
bgeu_eq_ok:
    addi x6, x0, 22
    bne  x5, x6, fail_313

    # ----------------------------------------------------------------
    # Test 14: bgeu — less than → not taken
    # ----------------------------------------------------------------
    addi x1, x0, 5
    addi x2, x0, 10              # 5 < 10
    addi x5, x0, 0
    bgeu x1, x2, bgeu_not_skip   # NOT taken
    addi x5, x0, 9               # SHOULD execute
    addi x5, x5, 9               # SHOULD execute → x5 = 18
bgeu_not_skip:
    addi x6, x0, 18
    bne  x5, x6, fail_314

    # ----------------------------------------------------------------
    # Test 15: backward branch — beq taken, skip back
    # ----------------------------------------------------------------
    addi x1, x0, 0
    addi x2, x0, 0
    addi x5, x0, 11
    beq  x1, x2, bw_target       # taken, forward
    addi x5, x0, 0               # POISON
    addi x5, x0, 0               # POISON
bw_target:
    addi x1, x1, 1               # x1 = 1
    addi x2, x0, 2
    bne  x1, x2, bw_target       # backward branch (x1=1 != 2 → taken)
    # x1 should now be 2 (loop ran once)
    addi x6, x0, 2
    bne  x1, x6, fail_315

    # ----------------------------------------------------------------
    # Test 16: verify both delay-slot slots are flushed on taken branch
    #    (put different poison in each to check independently)
    # ----------------------------------------------------------------
    addi x1, x0, 1
    addi x2, x0, 1
    addi x7, x0, 111             # safe value in x7
    addi x8, x0, 222             # safe value in x8
    beq  x1, x2, double_flush_ok # taken
    addi x7, x0, 0               # POISON slot 1 (ID): corrupt x7
    addi x8, x0, 0               # POISON slot 2 (IF): corrupt x8
double_flush_ok:
    addi x10, x0, 111
    bne  x7, x10, fail_316       # x7 should still be 111
    addi x10, x0, 222
    bne  x8, x10, fail_317       # x8 should still be 222

    # ----------------------------------------------------------------
    # Test 17: branch with x0 (never taken, but pipeline mustn't hang)
    # ----------------------------------------------------------------
    addi x5, x0, 0
    beq  x0, x1, fail_318        # x0=0, x1≠0, NOT taken (x0 hardwired 0)
    addi x5, x0, 19              # SHOULD execute
    addi x5, x5, 1               # SHOULD execute → x5 = 20
    addi x6, x0, 20
    bne  x5, x6, fail_318

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
fail_301:
    addi x28, x0, 301
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_301

fail_302:
    addi x28, x0, 302
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_302

fail_303:
    addi x28, x0, 303
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_303

fail_304:
    addi x28, x0, 304
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_304

fail_305:
    addi x28, x0, 305
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_305

fail_306:
    addi x28, x0, 306
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_306

fail_307:
    addi x28, x0, 307
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_307

fail_308:
    addi x28, x0, 308
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_308

fail_309:
    addi x28, x0, 309
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_309

fail_310:
    addi x28, x0, 310
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_310

fail_311:
    addi x28, x0, 311
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_311

fail_312:
    addi x28, x0, 312
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_312

fail_313:
    addi x28, x0, 313
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_313

fail_314:
    addi x28, x0, 314
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_314

fail_315:
    addi x28, x0, 315
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_315

fail_316:
    addi x28, x0, 316
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_316

fail_317:
    addi x28, x0, 317
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_317

fail_318:
    addi x28, x0, 318
    sw   x28, 0x3F0(x0)
    beq  x0, x0, fail_318
