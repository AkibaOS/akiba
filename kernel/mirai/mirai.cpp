/*
 * AkibaOS Mirai Kernel Entry Point
 *
 * Enhanced with timer system initialization for system timing
 * and the foundation of preemptive multitasking.
 */

#include <core/terminal.hpp>
#include <arch/gdt.hpp>
#include <arch/idt.hpp>
#include <arch/timer.hpp>

extern "C" void Mirai()
{
    /* Initialize all kernel subsystems */
    AkibaOS::Terminal::initialize();
    AkibaOS::GDT::initialize();
    AkibaOS::IDT::initialize();
    AkibaOS::Timer::initialize();  /* Add timer initialization */
    
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
    
    /* Test timer functionality */
    AkibaOS::Terminal::print_string("Testing timer system...\n");
    
    /* Display uptime every 2 seconds for demonstration */
    for (int i = 0; i < 5; i++) {
        AkibaOS::Timer::delay_ms(2000);  /* Wait 2 seconds */
        
        AkibaOS::Terminal::print_string("System uptime: ");
        uint64_t seconds = AkibaOS::Timer::get_uptime_seconds();
        
        /* Simple decimal display */
        if (seconds == 0) {
            AkibaOS::Terminal::print_char('0');
        } else {
            /* Convert to string manually since we don't have printf yet */
            char time_str[20];
            int digits = 0;
            uint64_t temp = seconds;
            
            while (temp > 0) {
                time_str[digits++] = '0' + (temp % 10);
                temp /= 10;
            }
            
            /* Print digits in reverse order */
            for (int j = digits - 1; j >= 0; j--) {
                AkibaOS::Terminal::print_char(time_str[j]);
            }
        }
        
        AkibaOS::Terminal::print_string(" seconds\n");
    }
    
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Green, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Timer system working correctly!\n");
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, 
                                 AkibaOS::Terminal::Color::Black);
    
    /* Enter idle loop with timer running */
    AkibaOS::Terminal::print_string("Entering idle loop - timer interrupts active...\n");
    while (true) {
        __asm__ volatile("hlt");  /* Wait for next interrupt */
    }
}