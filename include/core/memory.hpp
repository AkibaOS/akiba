/*
 * Physical Memory Management Header
 *
 * This module handles the allocation and tracking of physical memory pages.
 * It provides the foundation for all memory management in AkibaOS Mirai.
 *
 * The system uses a bitmap-based allocator to track 4KB pages of physical
 * memory. This is simple, efficient, and provides fast allocation/deallocation.
 */

#pragma once

#include <cstdint>
#include <cstddef>

namespace AkibaOS
{
    namespace Memory
    {
        /*
         * Memory Constants
         *
         * These define the fundamental memory parameters for the system.
         */
        constexpr size_t PAGE_SIZE = 4096;                    /* Standard x86-64 page size */
        constexpr size_t PAGE_ALIGN_MASK = PAGE_SIZE - 1;     /* Mask for page alignment */
        constexpr uintptr_t KERNEL_VIRTUAL_BASE = 0xFFFFFFFF80000000; /* Kernel virtual address */

        /*
         * Memory Region Types (from Multiboot)
         *
         * These correspond to the memory map entries provided by the bootloader.
         */
        enum class RegionType : uint32_t
        {
            AVAILABLE = 1,          /* Usable RAM */
            RESERVED = 2,           /* Reserved by hardware */
            ACPI_RECLAIMABLE = 3,   /* ACPI tables (can be reclaimed) */
            ACPI_NVS = 4,           /* ACPI non-volatile storage */
            BAD_MEMORY = 5          /* Defective RAM */
        };

        /*
         * Memory Map Entry Structure
         *
         * This matches the multiboot memory map format and describes
         * a contiguous region of physical memory.
         */
        struct MemoryMapEntry
        {
            uint32_t size;          /* Size of this entry structure */
            uint64_t base_addr;     /* Physical base address */
            uint64_t length;        /* Length in bytes */
            RegionType type;        /* Region type */
        } __attribute__((packed));

        /*
         * Physical Memory Statistics
         *
         * This structure tracks memory usage statistics for debugging
         * and system monitoring.
         */
        struct MemoryStats
        {
            uint64_t total_memory;      /* Total physical memory in bytes */
            uint64_t available_memory;  /* Available memory in bytes */
            uint64_t used_memory;       /* Currently used memory in bytes */
            uint64_t total_pages;       /* Total number of 4KB pages */
            uint64_t free_pages;        /* Number of free pages */
            uint64_t used_pages;        /* Number of used pages */
            uintptr_t bitmap_address;   /* Address of allocation bitmap */
            size_t bitmap_size;         /* Size of bitmap in bytes */
        };

        /*
         * Physical Memory Manager Class
         *
         * This class encapsulates all physical memory management functionality.
         * It uses a bitmap to track page allocation and provides allocation
         * and deallocation services.
         */
        class PhysicalMemoryManager
        {
        private:
            uint8_t* allocation_bitmap;     /* Bitmap tracking page allocation */
            uint64_t total_pages;           /* Total number of pages */
            uint64_t first_free_page;       /* Hint for faster allocation */
            MemoryStats stats;              /* Memory usage statistics */

            /*
             * Set a bit in the allocation bitmap
             *
             * @param page_index The page number to mark
             * @param used True to mark as used, false to mark as free
             */
            void set_page_bit(uint64_t page_index, bool used);

            /*
             * Get a bit from the allocation bitmap
             *
             * @param page_index The page number to check
             * @return True if page is used, false if free
             */
            bool get_page_bit(uint64_t page_index);

            /*
             * Find the first free page in the bitmap
             *
             * @return Page index of first free page, or UINT64_MAX if none
             */
            uint64_t find_first_free_page();

        public:
            /*
             * Initialize the physical memory manager
             *
             * This function sets up the bitmap allocator using information
             * from the multiboot memory map.
             *
             * @param memory_map_start Address of multiboot memory map
             * @param memory_map_length Length of memory map in bytes
             */
            void initialize(uintptr_t memory_map_start, uint32_t memory_map_length);

            /*
             * Allocate a single physical page
             *
             * @return Physical address of allocated page, or 0 if allocation failed
             */
            uintptr_t allocate_page();

            /*
             * Allocate multiple contiguous physical pages
             *
             * @param page_count Number of pages to allocate
             * @return Physical address of first page, or 0 if allocation failed
             */
            uintptr_t allocate_pages(size_t page_count);

            /*
             * Free a single physical page
             *
             * @param physical_address Physical address of page to free
             */
            void free_page(uintptr_t physical_address);

            /*
             * Free multiple contiguous physical pages
             *
             * @param physical_address Physical address of first page
             * @param page_count Number of pages to free
             */
            void free_pages(uintptr_t physical_address, size_t page_count);

            /*
             * Get current memory statistics
             *
             * @return Reference to memory statistics structure
             */
            const MemoryStats& get_stats() const;

            /*
             * Print memory map and statistics for debugging
             */
            void print_memory_info();
        };

        /*
         * Global instance of the physical memory manager
         */
        extern PhysicalMemoryManager physical_memory_manager;

        /*
         * Utility Functions
         */

        /*
         * Align an address to page boundary
         *
         * @param address The address to align
         * @return Address aligned to next page boundary
         */
        constexpr uintptr_t align_to_page(uintptr_t address)
        {
            return (address + PAGE_ALIGN_MASK) & ~PAGE_ALIGN_MASK;
        }

        /*
         * Check if an address is page-aligned
         *
         * @param address The address to check
         * @return True if address is page-aligned
         */
        constexpr bool is_page_aligned(uintptr_t address)
        {
            return (address & PAGE_ALIGN_MASK) == 0;
        }

        /*
         * Convert physical address to page index
         *
         * @param physical_address Physical address
         * @return Page index (address / PAGE_SIZE)
         */
        constexpr uint64_t address_to_page_index(uintptr_t physical_address)
        {
            return physical_address / PAGE_SIZE;
        }

        /*
         * Convert page index to physical address
         *
         * @param page_index Page index
         * @return Physical address (page_index * PAGE_SIZE)
         */
        constexpr uintptr_t page_index_to_address(uint64_t page_index)
        {
            return page_index * PAGE_SIZE;
        }

        /*
         * Initialize the memory management system
         *
         * This function should be called early in kernel initialization.
         * It requires multiboot information to detect available memory.
         *
         * @param multiboot_info Pointer to multiboot information structure
         */
        void initialize(void* multiboot_info);
    }
}