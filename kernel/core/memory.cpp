/*
 * Physical Memory Management Implementation
 *
 * This module implements a bitmap-based physical memory allocator for
 * AkibaOS Mirai. It tracks 4KB pages using a simple bitmap where each
 * bit represents one page (0 = free, 1 = used).
 *
 * The allocator is initialized using memory map information from the
 * multiboot bootloader, which tells us which regions of RAM are available.
 */

#include <core/memory.hpp>
#include <core/terminal.hpp>

#include <core/memory.hpp>
#include <core/terminal.hpp>

namespace AkibaOS
{
    namespace Memory
    {
        /* Global instance of the physical memory manager */
        PhysicalMemoryManager physical_memory_manager;

        /*
         * Multiboot Information Structure (simplified for safety)
         */
        struct MultibootInfo
        {
            uint32_t flags;
            uint32_t mem_lower;
            uint32_t mem_upper;
            uint32_t boot_device;
            uint32_t cmdline;
            uint32_t mods_count;
            uint32_t mods_addr;
            uint32_t syms[4];
            uint32_t mmap_length;
            uint32_t mmap_addr;
        };

        /*
         * Simple memory initialization without multiboot dependency
         *
         * For now, we'll assume a basic memory layout and implement
         * a minimal allocator. This avoids multiboot parsing issues.
         */
        void PhysicalMemoryManager::initialize(uintptr_t memory_map_start, uint32_t memory_map_length)
        {
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Initializing physical memory manager (basic mode)...\n");

            /* 
             * For safety, we'll assume a basic system with 16MB of RAM
             * This is a conservative estimate that should work on QEMU
             */
            uint64_t assumed_memory_size = 16 * 1024 * 1024; /* 16MB */
            
            /* Calculate pages and bitmap size */
            total_pages = assumed_memory_size / PAGE_SIZE;
            size_t bitmap_bytes = (total_pages + 7) / 8;

            /* Place bitmap at 2MB mark */
            uintptr_t bitmap_location = 0x200000;
            allocation_bitmap = reinterpret_cast<uint8_t*>(bitmap_location);

            /* Initialize all statistics */
            stats.total_memory = assumed_memory_size;
            stats.available_memory = assumed_memory_size;
            stats.total_pages = total_pages;
            stats.bitmap_address = bitmap_location;
            stats.bitmap_size = bitmap_bytes;

            /* Initialize bitmap - mark all as used first */
            for (size_t i = 0; i < bitmap_bytes; i++) {
                allocation_bitmap[i] = 0xFF;
            }

            /* Mark pages 1MB-16MB as available (skip first 1MB for safety) */
            uint64_t available_start_page = (1024 * 1024) / PAGE_SIZE; /* 1MB */
            uint64_t available_page_count = total_pages - available_start_page;

            stats.free_pages = 0;
            for (uint64_t page = available_start_page; page < total_pages; page++) {
                set_page_bit(page, false); /* Mark as free */
                stats.free_pages++;
            }

            /* Reserve bitmap area */
            uint64_t bitmap_start_page = bitmap_location / PAGE_SIZE;
            uint64_t bitmap_page_count = (bitmap_bytes + PAGE_SIZE - 1) / PAGE_SIZE;
            
            for (uint64_t page = bitmap_start_page; page < bitmap_start_page + bitmap_page_count; page++) {
                if (page < total_pages && !get_page_bit(page)) {
                    set_page_bit(page, true);
                    stats.free_pages--;
                }
            }

            /* Reserve kernel area (first 3MB for safety) */
            uint64_t kernel_end_page = (3 * 1024 * 1024) / PAGE_SIZE;
            for (uint64_t page = 0; page < kernel_end_page; page++) {
                if (page < total_pages && !get_page_bit(page)) {
                    set_page_bit(page, true);
                    stats.free_pages--;
                }
            }

            stats.used_pages = total_pages - stats.free_pages;
            stats.used_memory = stats.used_pages * PAGE_SIZE;
            first_free_page = kernel_end_page;

            Terminal::set_color(Terminal::Color::Green, Terminal::Color::Black);
            Terminal::print_string("Physical memory manager initialized (basic mode)\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
        }

        /*
         * Set a bit in the allocation bitmap
         */
        void PhysicalMemoryManager::set_page_bit(uint64_t page_index, bool used)
        {
            if (page_index >= total_pages) {
                return;
            }

            uint64_t byte_index = page_index / 8;
            uint8_t bit_index = page_index % 8;

            if (used) {
                allocation_bitmap[byte_index] |= (1 << bit_index);
            } else {
                allocation_bitmap[byte_index] &= ~(1 << bit_index);
            }
        }

        /*
         * Get a bit from the allocation bitmap
         */
        bool PhysicalMemoryManager::get_page_bit(uint64_t page_index)
        {
            if (page_index >= total_pages) {
                return true;
            }

            uint64_t byte_index = page_index / 8;
            uint8_t bit_index = page_index % 8;

            return (allocation_bitmap[byte_index] & (1 << bit_index)) != 0;
        }

        /*
         * Find the first free page in the bitmap
         */
        uint64_t PhysicalMemoryManager::find_first_free_page()
        {
            for (uint64_t page = first_free_page; page < total_pages; page++) {
                if (!get_page_bit(page)) {
                    first_free_page = page;
                    return page;
                }
            }

            for (uint64_t page = 0; page < first_free_page; page++) {
                if (!get_page_bit(page)) {
                    first_free_page = page;
                    return page;
                }
            }

            return UINT64_MAX;
        }

        /*
         * Allocate a single physical page
         */
        uintptr_t PhysicalMemoryManager::allocate_page()
        {
            uint64_t page_index = find_first_free_page();
            
            if (page_index == UINT64_MAX) {
                return 0;
            }

            set_page_bit(page_index, true);
            stats.free_pages--;
            stats.used_pages++;
            stats.used_memory += PAGE_SIZE;

            return page_index_to_address(page_index);
        }

        /*
         * Allocate multiple contiguous physical pages
         */
        uintptr_t PhysicalMemoryManager::allocate_pages(size_t page_count)
        {
            if (page_count == 0) return 0;
            if (page_count == 1) return allocate_page();

            for (uint64_t start_page = first_free_page; start_page <= total_pages - page_count; start_page++) {
                bool found_contiguous = true;

                for (size_t i = 0; i < page_count; i++) {
                    if (get_page_bit(start_page + i)) {
                        found_contiguous = false;
                        break;
                    }
                }

                if (found_contiguous) {
                    for (size_t i = 0; i < page_count; i++) {
                        set_page_bit(start_page + i, true);
                    }

                    stats.free_pages -= page_count;
                    stats.used_pages += page_count;
                    stats.used_memory += page_count * PAGE_SIZE;

                    return page_index_to_address(start_page);
                }
            }

            return 0;
        }

        /*
         * Free a single physical page
         */
        void PhysicalMemoryManager::free_page(uintptr_t physical_address)
        {
            if (!is_page_aligned(physical_address)) {
                return;
            }

            uint64_t page_index = address_to_page_index(physical_address);
            
            if (page_index >= total_pages || !get_page_bit(page_index)) {
                return;
            }

            set_page_bit(page_index, false);
            stats.free_pages++;
            stats.used_pages--;
            stats.used_memory -= PAGE_SIZE;

            if (page_index < first_free_page) {
                first_free_page = page_index;
            }
        }

        /*
         * Free multiple contiguous physical pages
         */
        void PhysicalMemoryManager::free_pages(uintptr_t physical_address, size_t page_count)
        {
            for (size_t i = 0; i < page_count; i++) {
                free_page(physical_address + (i * PAGE_SIZE));
            }
        }

        /*
         * Get current memory statistics
         */
        const MemoryStats& PhysicalMemoryManager::get_stats() const
        {
            return stats;
        }

        /*
         * Print memory information - simplified version
         */
        void PhysicalMemoryManager::print_memory_info()
        {
            Terminal::set_color(Terminal::Color::Cyan, Terminal::Color::Black);
            Terminal::print_string("=== MEMORY INFORMATION ===\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);

            Terminal::print_string("Memory Manager: Basic Mode (16MB assumed)\n");
            Terminal::print_string("Page Size: 4096 bytes\n");
            Terminal::print_string("Total Pages: ");
            
            /* Simple number display */
            uint64_t pages = stats.total_pages;
            if (pages > 1000) {
                Terminal::print_string("4000+");
            } else {
                Terminal::print_string("many");
            }
            Terminal::print_string("\n");
            
            Terminal::print_string("Memory allocation system ready\n");
        }

        /*
         * Safe initialization that doesn't rely on multiboot
         */
        void initialize(void* multiboot_info)
        {
            /* For now, ignore multiboot_info to avoid crashes */
            /* We'll implement proper multiboot parsing later when it's safer */
            
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Note: Using basic memory detection (multiboot parsing disabled)\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);

            /* Initialize with basic parameters */
            physical_memory_manager.initialize(0, 0);
        }
    }
}