li s2, 64
li s0, 0x01000000
li a0, 0
li a1, 800
li a3, 600
li s10, 217
loop1:
    li a2, 570
loop2:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loop2
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loop1
    li s2, 187
    li s0, 0x01000000
    li a0, 0
    li a1, 800
    li a3, 570
loopmain11:
    li a2, 0
loopmain111:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loopmain111
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loopmain11
    li t0, 450000
    li t1, 750
    li t2, 800
mwrite:
    li s2, 187
    li s0, 0x01000000
    li s3, 30000
    add s0, s0, t0
    add s0, s0, s3
    addi a0, t1, 50
    addi a1, t2, 50
    li s3, 800
    bne s3, a0, mcontinue
    li s0, 0x01000000
    li a0, 0
    li a1, 50
mcontinue:
    li a3, 570
loopmain:
    li a2, 0
loopmain1:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loopmain1
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loopmain
    li s9, 217
    beq s10, s9, orange
    li s10, 217
    beq zero, zero, mcontinue2
orange:
    li s10, 244
mcontinue2:
    addi s2, s10, 0
    li s0, 0x01000000
    li a0, 225000
    add s0, s0, a0
    li a0, 375
    li a1, 401
bird1:
    li t5, 400
    sub t6, t5, a0
    addi a2, t6, 255
    li a3, 306
    sub a3, a3, t6
bird2:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, bird2
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, bird1
    li s0, 0x01000000
    li a0, 240000
    add s0, s0, a0
    li a0, 400
    li a1, 426
bird3:
    li t5, 400
    sub t6, a0, t5
    addi a2, t6, 255
    li a3, 306
    sub a3, a3, t6
bird4:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, bird4
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, bird3
    li s2, 255
    li s0, 0x01000000
    li a0, 219000
    add s0, s0, a0
    li a0, 365
    li a1, 376
    li a3, 284
wing1:
    li t5, 375
    sub t6, t5, a0
    addi a2, t6, 273
wing2:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, wing2
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, wing1
    li s0, 0x01000000
    li a0, 225000
    add s0, s0, a0
    li a0, 375
    li a1, 386
    li a3, 284
wing3:
    li t5, 375
    sub t6, a0, t5
    addi a2, t6, 273
wing4:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, wing4
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, wing3
    li s2, 224
    li s0, 0x01000000
    li a0, 243000
    add s0, a0, s0
    li a0, 405
    li a1, 427
    li a3, 294
peak1:
    li a2, 285
peak2:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, peak2
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, peak1
    li s2, 0
    li s0, 0x01000000
    li a0, 246000
    add s0, a0, s0
    li a0, 410
    li a1, 427
    li a3, 291
peak3:
    li a2, 290
peak4:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, peak4
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, peak3
    li s2, 255
    li s0, 0x01000000
    li a0, 241200
    add s0, a0, s0
    li a0, 402
    li a1, 412
    li a3, 278
eye3:
    li a2, 268
eye4:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, eye4
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, eye3
    li s2, 0
    li s0, 0x01000000
    li a0, 244200
    add s0, a0, s0
    li a0, 407
    li a1, 410
    li a3, 275
eye1:
    li a2, 272
eye2:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, eye2
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, eye1
    li s2, 53
    li s0, 0x01000000
    addi a0, t0, 0
    add s0, s0, a0
    addi a0, t1, 0
    addi a1, t2, 0
    li a3, 200
loop3:
    li a2, 0
loop4:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loop4
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loop3
    li s2, 53
    li s0, 0x01000000
    addi a0, t0, 0
    add s0, s0, a0
    addi a0, t1, 0
    addi a1, t2, 0
    li a3, 570
loop7:
    li a2, 370
loop8:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loop8
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loop7
    li s2, 49
    li s0, 0x01000000
    addi a0, t0, 0
    add s0, s0, a0
    addi a0, t1, 0
    addi a1, t2, 0
    li a3, 220
loop5:
    li a2, 200
loop6:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loop6
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loop5
    li s2, 49
    li s0, 0x01000000
    addi a0, t0, 0
    add s0, s0, a0
    addi a0, t1, 0
    addi a1, t2, 0
    li a3, 370
loop9:
    li a2, 350
loop10:
    add a4, a2, s0
    sb s2, (a4)
    addi a2, a2, 1
    bne a2, a3, loop10
    addi s0, s0, 600
    addi a0, a0, 1
    bne a0, a1, loop9
    li a0, 0
    li a1, 1500000
    li a2, 1
wait:
    addi a2, a2, 1
    addi a0, a0, 1
    bne a0, a1, wait
    beq t1, zero, setup
    li a0, -30000
    add t0, t0, a0
    addi t1, t1, -50 
    addi t2, t2, -50
    beq zero, zero, mwrite
setup:
    li t0, 450000
    li t1, 750
    li t2, 800
    beq zero, zero, mwrite
    jr ra