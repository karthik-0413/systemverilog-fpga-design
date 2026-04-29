/* Linker script for RISC-V RV32I processor with 4KB BRAM at address 0 */

MEMORY
{
  /* 4KB combined instruction/data memory starting at address 0 */
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

/* Entry point */
ENTRY(_start)

/* Sections */
SECTIONS
{
    /* Code section - starts at address 0 (reset vector) */
    .text :
    {
        KEEP(*(.text.init))    /* Keep startup code at beginning */
        *(.text*)              /* All other code */
        . = ALIGN(4);
    } > ram

    /* Read-only data section */
    .rodata :
    {
        *(.rodata*)
        . = ALIGN(4);
    } > ram

    /* Initialized data section */
    .data :
    {
        *(.data*)
        . = ALIGN(4);
    } > ram

    /* Uninitialized data section */
    .bss :
    {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
        . = ALIGN(4);
    } > ram

    /* Stack allocation - place at end of memory */
    .stack (NOLOAD) :
    {
        . = . + 0x200;  /* 512 bytes for stack */
        __stack_top = .;
    } > ram

    /* Define symbols for memory boundaries */
    _memory_start = ORIGIN(ram);
    _memory_end = ORIGIN(ram) + LENGTH(ram);
}
