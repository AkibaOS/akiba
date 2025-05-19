/*
 * Global Descriptor Table (GDT) Header
 *
 * This header defines the structures and constants needed for the Global Descriptor Table,
 * a fundamental data structure required by the x86/x86_64 CPU architecture that defines
 * memory segments and their properties.
 *
 * In 64-bit mode (long mode), segmentation is largely replaced by paging, but the GDT
 * is still required for certain CPU operations including privilege levels (rings) and
 * task state management.
 */

#pragma once

#include <cstdint>

namespace AkibaOS
{
    namespace GDT
    {
        /*
         * GDT Entry Structure (8 bytes)
         *
         * This represents a single segment descriptor in the Global Descriptor Table.
         * Each entry is a packed 8-byte structure that defines a memory segment.
         * The structure follows the Intel x86/x86_64 specification for segment descriptors.
         */
        struct Entry
        {
            uint16_t limit_low;    /* Bits 0-15 of the segment limit */
            uint16_t base_low;     /* Bits 0-15 of the base address */
            uint8_t base_middle;   /* Bits 16-23 of the base address */
            uint8_t access;        /* Access control bits and type information */
            uint8_t granularity;   /* Granularity bit, size bit, and limit bits 16-19 */
            uint8_t base_high;     /* Bits 24-31 of the base address */
        } __attribute__((packed)); /* Ensures the compiler doesn't add padding bytes */

        /*
         * GDT Pointer Structure
         *
         * This structure is used with the LGDT instruction to load the GDT.
         * It contains the size of the table (minus 1) and the physical address
         * of the first entry.
         */
        struct Pointer
        {
            uint16_t size;         /* Size of the GDT in bytes, minus 1 */
            uint64_t address;      /* Linear address of the GDT (64-bit) */
        } __attribute__((packed)); /* Must be packed for proper memory layout */

        /*
         * Access Byte Flags for GDT Entries
         *
         * These flags control segment access permissions and characteristics.
         * They form the 'access' byte in each GDT entry.
         */
        enum AccessFlags : uint8_t
        {
            PRESENT = 0x80,              /* Segment is present in memory (set for all valid segments) */
            PRIVILEGE_KERNEL = 0x00,     /* Ring 0 (kernel) privilege level */
            PRIVILEGE_USER = 0x60,       /* Ring 3 (user mode) privilege level */
            DESCRIPTOR_TYPE = 0x10,      /* Must be 1 for code/data segments (0 for system segments) */
            EXECUTABLE = 0x08,           /* Segment is executable (code) when set, data when clear */
            DIRECTION_CONFORMING = 0x04, /* Direction bit for data or conforming bit for code */
            READ_WRITE = 0x02,           /* Readable bit for code, writable bit for data */
            ACCESSED = 0x01              /* Set by CPU when segment is accessed, can be pre-set to 1 */
        };

        /*
         * Granularity Byte Flags for GDT Entries
         *
         * These flags control segment size and granularity.
         * They form the upper 4 bits of the 'granularity' byte in each entry.
         */
        enum GranularityFlags : uint8_t
        {
            PAGE_GRANULARITY = 0x80, /* Limit is in 4KiB pages (not bytes) when set */
            SIZE_32BIT = 0x40,       /* 32-bit protected mode segment (not used in long mode) */
            LONG_MODE = 0x20         /* 64-bit code segment (only valid for code segments) */
        };

        /*
         * Initializes the Global Descriptor Table
         *
         * This function sets up the GDT entries and loads the table into the CPU.
         * Must be called early in the kernel initialization process.
         */
        void initialize();
    }
}