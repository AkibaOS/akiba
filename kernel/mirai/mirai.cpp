/*
 * AkibaOS Mirai Kernel Entry Point
 *
 * Enhanced with exception handling testing to verify our
 * improved debugging capabilities work correctly.
 */

#include <core/terminal.hpp>
#include <arch/gdt.hpp>
#include <arch/idt.hpp>

extern "C" void Mirai()
{
    /* Initialize all kernel subsystems */
    AkibaOS::Terminal::initialize();
    AkibaOS::GDT::initialize();
    AkibaOS::IDT::initialize();
    
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
    AkibaOS::Terminal::print_string("Mirai kernel initialized and ready.\n");
    
    /* Test regular interrupt handling */
    AkibaOS::Terminal::print_string("Testing interrupt handling...\n");
    __asm__ volatile("int $0x80");
    
    /* Test exception handling */
    AkibaOS::Terminal::print_string("Testing exception handling...\n");
    AkibaOS::Terminal::print_string("Triggering division by zero exception in 3 seconds...\n");
    
    /* Simple delay loop */
    for (volatile int i = 0; i < 50000000; i++) {
        /* Just wait */
    }
    
    /* Trigger a division by zero exception */
    volatile int a = 1;
    volatile int b = 0;
    volatile int c = a / b;  /* This will cause a divide by zero exception */
    
    /* This line should never be reached */
    AkibaOS::Terminal::print_string("ERROR: Exception handling failed!\n");
    
    /* Idle loop */
    while (true) {
        __asm__ volatile("hlt");
    }
}