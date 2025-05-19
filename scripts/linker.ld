ENTRY(start)

SECTIONS
{
    . = 1M;

    .boot :
    {
        KEEP(*(.akiba_multiboot_header))
    }

    .text :
    {
        *(.text)
    }
}