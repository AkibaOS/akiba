/*
 * AkibaOS Mirai Kernel Linker Script
 *
 * This script defines how the kernel binary is laid out in memory.
 * It ensures proper separation between different types of data
 * and sets appropriate permissions for each section.
 */

ENTRY(start)

SECTIONS
{
    /* Start the kernel at 1MB in physical memory */
    . = 1M;

    /* Multiboot header section - must be at the very beginning */
    .boot :
    {
        KEEP(*(.akiba_multiboot_header))
    }

    /* Code section - executable but not writable */
    .text ALIGN(4K) : AT(ADDR(.text))
    {
        *(.text .text.*)
    }

    /* Read-only data section */
    .rodata ALIGN(4K) : AT(ADDR(.rodata))
    {
        *(.rodata .rodata.*)
    }

    /* Initialized data section - writable but not executable */
    .data ALIGN(4K) : AT(ADDR(.data))
    {
        *(.data .data.*)
    }

    /* Uninitialized data section - writable but not executable */
    .bss ALIGN(4K) : AT(ADDR(.bss))
    {
        *(COMMON)
        *(.bss .bss.*)
    }
}