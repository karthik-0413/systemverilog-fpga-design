/* Minimal startup file for RISC-V RV32I processor */
.global _start
.global main

.section .text.init
_start:
    /* Initialize stack pointer */
    la sp, __stack_top
    
    /* Zero out BSS section */
    la a0, __bss_start
    la a1, __bss_end
    beq a0, a1, bss_done
    
bss_loop:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, bss_loop

bss_done:
    /* Call main function */
    call main
    
    /* Infinite loop after main returns */
hang:
    j hang
