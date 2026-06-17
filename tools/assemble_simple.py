#!/usr/bin/env python3
"""Two-pass RISC-V RV32I assembler with label support.

Supported instructions:
  R-type: add, sub, and, or, xor, slt, sltu, sll, srl, sra
  I-type: addi, andi, ori, xori, slti, sltiu, slli, srli, srai
  Load:   lw
  Store:  sw
  Branch: beq, bne, blt, bge, bltu, bgeu
  Jump:   jal, jalr
  Upper:  lui, auipc
  Pseudo: nop  → addi x0, x0, 0
"""

import sys
import re

# ---------------------------------------------------------------------------
# register parsing
# ---------------------------------------------------------------------------
REG_RE = re.compile(r'x([0-9]|[12][0-9]|3[01])$')

def parse_reg(s):
    s = s.strip()
    m = REG_RE.match(s)
    if not m:
        raise ValueError(f"Invalid register: {s}")
    return int(m.group(1))


# ---------------------------------------------------------------------------
# immediate helpers
# ---------------------------------------------------------------------------
def parse_imm(s):
    s = s.strip()
    if s.startswith('0x') or s.startswith('0X'):
        return int(s, 16)
    return int(s, 0)


def sign_extend(value, bits):
    mask = (1 << bits) - 1
    value &= mask
    if value & (1 << (bits - 1)):
        return value - (1 << bits)
    return value


# ---------------------------------------------------------------------------
# instruction encoders
# ---------------------------------------------------------------------------
def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7f) << 25) | ((rs2 & 0x1f) << 20) | \
           ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | \
           ((rd  & 0x1f) << 7)  | (opcode & 0x7f)


def encode_i(imm, rs1, funct3, rd, opcode):
    imm12 = imm & 0xfff
    return (imm12 << 20) | ((rs1 & 0x1f) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def encode_s(imm, rs2, rs1, funct3, opcode):
    imm12 = imm & 0xfff
    imm11_5 = (imm12 >> 5) & 0x7f
    imm4_0  = imm12 & 0x1f
    return (imm11_5 << 25) | ((rs2 & 0x1f) << 20) | \
           ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | \
           (imm4_0 << 7) | (opcode & 0x7f)


def encode_b(imm, rs2, rs1, funct3, opcode):
    # B-type immediate is a signed byte offset.
    # Encoded bits: imm[12|10:5|4:1|11], imm[0] is always 0.
    if imm % 2 != 0:
        raise ValueError(f"B-type branch offset must be 2-byte aligned: {imm}")
    if imm < -4096 or imm > 4094:
        raise ValueError(f"B-type branch offset out of range: {imm}")

    imm13 = imm & 0x1fff

    bit12    = (imm13 >> 12) & 0x1
    bit11    = (imm13 >> 11) & 0x1
    bits10_5 = (imm13 >> 5)  & 0x3f
    bits4_1  = (imm13 >> 1)  & 0xf

    return (bit12 << 31) | (bits10_5 << 25) | ((rs2 & 0x1f) << 20) | \
           ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | \
           (bits4_1 << 8) | (bit11 << 7) | (opcode & 0x7f)


def encode_u(imm, rd, opcode):
    imm20 = imm & 0xfffff
    return (imm20 << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def encode_j(imm, rd, opcode):
    imm21 = imm & 0x1fffff                # J-type: 21-bit immediate (bit0 always 0)
    imm_shift = imm21 >> 1                # discard bit0, keep imm[20:1]
    bit20     = (imm_shift >> 19) & 0x1
    bits10_1  = imm_shift & 0x3ff
    bit11     = (imm_shift >> 10) & 0x1
    bits19_12 = (imm_shift >> 11) & 0xff
    return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | \
           (bits10_1 << 21) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


# ---------------------------------------------------------------------------
# opcode / funct constants
# ---------------------------------------------------------------------------
OP_RTYPE  = 0x33
OP_ITYPE  = 0x13
OP_LOAD   = 0x03
OP_STORE  = 0x23
OP_BRANCH = 0x63
OP_JAL    = 0x6f
OP_JALR   = 0x67
OP_LUI    = 0x37
OP_AUIPC  = 0x17

FUNCT3_BEQ  = 0x0
FUNCT3_BNE  = 0x1
FUNCT3_BLT  = 0x4
FUNCT3_BGE  = 0x5
FUNCT3_BLTU = 0x6
FUNCT3_BGEU = 0x7


# ---------------------------------------------------------------------------
# line cleaning
# ---------------------------------------------------------------------------
def clean_line(line):
    """Strip comments and whitespace; return None for empty/label-only lines."""
    line = line.split('#')[0].split('//')[0].strip()
    if not line:
        return None
    return line


def is_label(line):
    return line.endswith(':') and not any(c in line for c in ' ,()')


def tokenize(line):
    """Split an instruction line into tokens: opcode + operands."""
    parts = re.split(r'[\s,()]+', line)
    return [p for p in parts if p != '']


# ---------------------------------------------------------------------------
# two-pass assembler
# ---------------------------------------------------------------------------
def assemble_file(src, dst):
    with open(src, 'r') as f:
        raw_lines = f.readlines()

    # ---- Pass 1: collect label addresses --------------------------------
    labels = {}
    pc = 0
    for ln in raw_lines:
        cl = clean_line(ln)
        if cl is None:
            continue
        if is_label(cl):
            name = cl[:-1]  # strip trailing ':'
            if name in labels:
                raise ValueError(f"Duplicate label: {name}")
            labels[name] = pc
        elif cl.startswith('.'):
            continue  # assembler directives ignored
        else:
            pc += 4

    # ---- Pass 2: assemble -----------------------------------------------
    pc = 0
    instrs = []
    for ln in raw_lines:
        cl = clean_line(ln)
        if cl is None or cl.startswith('.') or is_label(cl):
            continue
        try:
            code = assemble_line(cl, labels, pc)
        except Exception as e:
            print(f"Error assembling line: {ln.strip()} -> {e}")
            raise
        if code is not None:
            instrs.append(code)
            pc += 4

    with open(dst, 'w') as f:
        for ic in instrs:
            f.write(f"{ic:08x}\n")


def resolve_operand(tok, labels, pc):
    """If tok is a known label, return (target_address - pc) as byte offset.
    Otherwise parse it as an immediate integer."""
    if tok in labels:
        return labels[tok] - pc
    return parse_imm(tok)

def check_signed_range(value, bits, name="immediate"):
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if value < lo or value > hi:
        raise ValueError(f"{name} out of signed {bits}-bit range: {value}")


def check_unsigned_range(value, bits, name="immediate"):
    lo = 0
    hi = (1 << bits) - 1
    if value < lo or value > hi:
        raise ValueError(f"{name} out of unsigned {bits}-bit range: {value}")
# ---------------------------------------------------------------------------
# single-line assembler
# ---------------------------------------------------------------------------
def assemble_line(line, labels, pc):
    tokens = tokenize(line)
    op = tokens[0]

    # ---- Pseudo-instructions ----
    if op == 'nop':
        return encode_i(0, 0, 0, 0, OP_ITYPE)   # addi x0, x0, 0

    # ---- R-type ----
    if op in ('add', 'sub', 'and', 'or', 'xor', 'slt', 'sltu', 'sll', 'srl', 'sra'):
        rd  = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        rs2 = parse_reg(tokens[3])
        rtype_map = {
            'add':  (0x00, 0x0), 'sub':  (0x20, 0x0),
            'sll':  (0x00, 0x1), 'slt':  (0x00, 0x2),
            'sltu': (0x00, 0x3), 'xor':  (0x00, 0x4),
            'srl':  (0x00, 0x5), 'sra':  (0x20, 0x5),
            'or':   (0x00, 0x6), 'and':  (0x00, 0x7),
        }
        f7, f3 = rtype_map[op]
        return encode_r(f7, rs2, rs1, f3, rd, OP_RTYPE)

       # ---- I-type ALU ----
    if op in ('addi', 'andi', 'ori', 'xori', 'slti', 'sltiu', 'slli', 'srli', 'srai'):
        rd  = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        imm = parse_imm(tokens[3])

        itype_map = {
            'addi':  0x0, 'slli':  0x1, 'slti':  0x2,
            'sltiu': 0x3, 'xori':  0x4,
            'srli':  0x5, 'srai':  0x5, 'ori':   0x6, 'andi': 0x7,
        }
        f3 = itype_map[op]

        # RV32I shift-immediate: shamt is 5 bits, 0..31
        if op in ('slli', 'srli', 'srai'):
            check_unsigned_range (imm, 5, "shift amount")
            if op == 'slli':
                return encode_r(0x00, imm, rs1, f3, rd, OP_ITYPE)
            if op == 'srli':
                return encode_r(0x00, imm, rs1, f3, rd, OP_ITYPE)
            if op == 'srai':
                return encode_r(0x20, imm, rs1, f3, rd, OP_ITYPE)

        check_signed_range (imm, 12, "I-type immediate")
        return encode_i(imm, rs1, f3, rd, OP_ITYPE)

    # ---- Load ----
     
     
    if op in ('lb', 'lh', 'lw', 'lbu', 'lhu'):
        rd  = parse_reg(tokens[1])
        imm = parse_imm(tokens[2])
        rs1 = parse_reg(tokens[3])
        check_signed_range(imm, 12, f"{op} immediate")

        load_funct3 = {
            'lb':  0x0,
            'lh':  0x1,
            'lw':  0x2,
            'lbu': 0x4,
            'lhu': 0x5,
        }

        return encode_i(imm, rs1, load_funct3[op], rd, OP_LOAD)

        # ---- Store ----
    if op in ('sb', 'sh', 'sw'):
        rs2 = parse_reg(tokens[1])
        imm = parse_imm(tokens[2])
        rs1 = parse_reg(tokens[3])
        check_signed_range(imm, 12, f"{op} immediate")

        store_funct3 = {
            'sb': 0x0,
            'sh': 0x1,
            'sw': 0x2,
        }

        return encode_s(imm, rs2, rs1, store_funct3[op], OP_STORE)

    # ---- Branches (support labels as immediate) ----
    if op in ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'):
        rs1   = parse_reg(tokens[1])
        rs2   = parse_reg(tokens[2])
        imm   = resolve_operand(tokens[3], labels, pc)
        funct3_map = {
            'beq':  FUNCT3_BEQ,  'bne':  FUNCT3_BNE,
            'blt':  FUNCT3_BLT,  'bge':  FUNCT3_BGE,
            'bltu': FUNCT3_BLTU, 'bgeu': FUNCT3_BGEU,
        }
        return encode_b(imm, rs2, rs1, funct3_map[op], OP_BRANCH)

    # ---- JAL ----
    if op == 'jal':
        rd  = parse_reg(tokens[1])
        imm = resolve_operand(tokens[2], labels, pc)
        return encode_j(imm, rd, OP_JAL)

    # ---- JALR ----
    
    if op == 'jalr':
        rd  = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        imm = parse_imm(tokens[3])
        check_signed_range(imm, 12, "jalr immediate")
        return encode_i(imm, rs1, 0x0, rd, OP_JALR)

    # ---- LUI ----
    if op == 'lui':
        rd  = parse_reg(tokens[1])
        imm = parse_imm(tokens[2])
        return encode_u(imm, rd, OP_LUI)

    # ---- AUIPC ----
    if op == 'auipc':
        rd  = parse_reg(tokens[1])
        imm = parse_imm(tokens[2])
        return encode_u(imm, rd, OP_AUIPC)

    raise ValueError(f"Unsupported instruction: {line}")


# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) < 3:
        print("Usage: assemble_simple.py <src.s> <out.hex>")
        sys.exit(1)
    assemble_file(sys.argv[1], sys.argv[2])
    print(f"Assembled {sys.argv[1]} -> {sys.argv[2]}")


if __name__ == '__main__':
    main()
