/*
 * AkibaOS Mirai Kernel Entry Point
 *
 * Enhanced with physical memory management initialization.
 * The kernel now properly manages physical memory using a bitmap allocator.
 */

#include <core/terminal.hpp>
#include <arch/gdt.hpp>
#include <arch/idt.hpp>
#include <arch/timer.hpp>
#include <core/memory.hpp>

extern "C" void Mirai(void* multiboot_info)
{
    /* Initialize terminal output first */
    AkibaOS::Terminal::initialize();
    
    /* Display welcome messages */
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Cyan, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Welcome to AkibaOS!\n");

    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Yellow, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Drifting from abyss towards the infinite!\n");
    
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Magenta, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("===============================================\n");
    
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, 
                                 AkibaOS::Terminal::Color::Black);
    
    /* Initialize core kernel subsystems one by one with error checking */
    AkibaOS::Terminal::print_string("Initializing GDT...\n");
    AkibaOS::GDT::initialize();
    
    AkibaOS::Terminal::print_string("Initializing IDT...\n");
    AkibaOS::IDT::initialize();
    
    AkibaOS::Terminal::print_string("Initializing Memory Manager...\n");
    AkibaOS::Memory::initialize(multiboot_info);
    
    AkibaOS::Terminal::print_string("Initializing Timer...\n");
    AkibaOS::Timer::initialize();
    
    AkibaOS::Terminal::print_string("Mirai kernel initialized and ready.\n");
    
    /* Test memory allocation with error checking */
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Green, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Testing memory allocation...\n");
    
    uintptr_t page1 = AkibaOS::Memory::physical_memory_manager.allocate_page();
    if (page1 != 0) {
        AkibaOS::Terminal::print_string("Single page allocation: SUCCESS\n");
        AkibaOS::Memory::physical_memory_manager.free_page(page1);
        AkibaOS::Terminal::print_string("Single page free: SUCCESS\n");
    } else {
        AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Red, 
                                     AkibaOS::Terminal::Color::Black);
        AkibaOS::Terminal::print_string("Memory allocation: FAILED\n");
    }
    
    /* Display memory information */
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Memory::physical_memory_manager.print_memory_info();
    
    /* Enter idle loop */
    AkibaOS::Terminal::print_string("Entering idle loop...\n");
    while (true) {
        __asm__ volatile("hlt");
    }
}