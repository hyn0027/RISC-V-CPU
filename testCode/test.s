    .org 0x0
    .global _start
    .text
_start:

    addi t0, zero, 0x1a     # t0: 0x1a
    addi t1, zero, 0x1b     
    sub  t1, t0, t1         # t1: -1
    addi a0, zero, 0x1      # a0: 1
    addi a1, zero, 0x1      # a1: 1
    addi a2, zero, 0x1      # a2: 1
    addi a3, zero, 0x1      # a3: 1
    bgeu t1, t0, .TEST_BGE  # unsigned(-1) >= 0x1a
    addi a0, a0, 0x1
.TEST_BGE:
    bge t0, t1, .TEST_BLTU  # 0x1a >= -1
    addi a1, a1, 0x1
.TEST_BLTU:
    bltu t0, t1, .TEST_BLT  # 0x1a < unsigned(-1)
    addi a2, a2, 0x1
.TEST_BLT:
    blt t1, t0, .TEST_SLT   # -1 < 0x1a
    addi a3, a3, 0x1
.TEST_SLT:
    slt a4, t1, t0          # -1 < 0x1a
    sltu a5, t0, t1         # 0x1a < unsigned(-1)
    slti a6, t1, 0x1        # -1 < 1
    sltiu a7, t0, -1        # 1 < unsigned(-1)
.TEST_SRA:
    addi a1, zero, 0        # a1: 0
    lui a1, 0xF0000         # a1: 0xF0000000
    sra s3, a1, a2          # 0xF0000000 >> 1 (arithmatic)
    # srai, a3, a1, 0x1
    srl a4, a1, a2          # 0xF0000000 >> 1 (logic)
    srli a5, a1, 0x1        # 0xF0000000 >> 1 (logic)
    sll a6, a1, a2          # 0xF0000000 << 1
    slli a7, a1, 0x1        # 0xF0000000 << 1
.TEST_LOAD:
    lui s8, 0x80400         
    addi s8, s8, 0x100      # s8: 0x80400100
    lui s9, 0x87654         
    addi s9, s9, 0x321      # s9: 0x87654321
    sw t0, (s8)  
    sw s9, -4(s8) 
    sh a2, -8(s8)
    lh a2, -8(s8) 
    addi a1, zero, 0
    lui a1, 0x1
    addi a1, a1, -4
    add s3, s8, a1
    sw t1, (s3)   
    lh s1, -4(s8)
    lbu s1, -4(s8)
    lhu s1, -4(s8)
    jr ra


