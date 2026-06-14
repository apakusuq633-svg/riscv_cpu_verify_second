    .section .text
    .globl _start
    .org 0x0
_start:
    addi x1,x0,10
   
    addi x2,x1,10
   
    sw x2,0(x0)
    
    lw x3,0(x0)
    
    add x4,x2,x3
    
    sub x5,x4,x3
    
   loop:
    addi x3, x3, 3
    nop
    nop
    nop

    addi x1, x1, 1
    nop
    nop
    nop

    blt x1, x2, loop
    nop
    nop
    nop
    
    sw x3,4(x5)
   
    addi x5,x5,4
   nop
   nop
    lw x4,0(x5)
    
  

