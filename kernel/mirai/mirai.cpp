/*
 * AkibaOS Mirai Kernel Entry Point
 *
 * This is the main entry point for the AkibaOS Mirai kernel. It initializes
 * all kernel subsystems and provides a basic testing environment for
 * system calls and kernel functionality.
 */

#include <core/terminal.hpp>
#include <arch/gdt.hpp>
#include <arch/idt.hpp>
#include <arch/timer.hpp>
#include <core/memory.hpp>
#include <core/syscalls.hpp>

extern "C" void Mirai(void* multiboot_info)
{
    /* Initialize terminal output first so we can see what's happening */
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
    
    /* Initialize all kernel subsystems in order */
    AkibaOS::Terminal::print_string("Initializing GDT...\n");
    AkibaOS::GDT::initialize();
    
    AkibaOS::Terminal::print_string("Initializing IDT...\n");
    AkibaOS::IDT::initialize();
    
    AkibaOS::Terminal::print_string("Initializing Memory Manager...\n");
    AkibaOS::Memory::initialize(multiboot_info);
    
    AkibaOS::Terminal::print_string("Initializing System Calls...\n");
    AkibaOS::SystemCalls::initialize();
    
    AkibaOS::Terminal::print_string("Initializing Timer...\n");
    AkibaOS::Timer::initialize();
    
    AkibaOS::Terminal::print_string("Mirai kernel initialized and ready.\n");
    
    /* Test system call interface */
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Green, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Testing system call interface...\n");
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, 
                                 AkibaOS::Terminal::Color::Black);
    
    /* Test sys_write system call */
    const char* test_message = "Hello from system call!";
    int64_t write_result;
    __asm__ volatile(
        "mov $2, %%rax\n"          /* SYS_WRITE */
        "mov $1, %%rdi\n"          /* STDOUT */
        "mov %1, %%rsi\n"          /* message buffer */
        "mov $24, %%rdx\n"         /* message length (24 chars) */
        "int $0x80\n"              /* trigger system call */
        "mov %%rax, %0\n"          /* store return value */
        : "=r"(write_result)
        : "r"(test_message)
        : "rax", "rdi", "rsi", "rdx"
    );
    
    AkibaOS::Terminal::print_string("\n");
    
    /* Test sys_getpid system call */
    int64_t pid;
    __asm__ volatile(
        "mov $4, %%rax\n"          /* SYS_GETPID */
        "int $0x80\n"              /* trigger system call */
        "mov %%rax, %0\n"          /* store result */
        : "=r"(pid)
        :
        : "rax"
    );
    
    AkibaOS::Terminal::print_string("System call write returned: ");
    if (write_result == 24) {
        AkibaOS::Terminal::print_string("24 (success)\n");
    } else {
        AkibaOS::Terminal::print_string("error\n");
    }
    
    AkibaOS::Terminal::print_string("Current PID: ");
    if (pid == 1) {
        AkibaOS::Terminal::print_string("1 (kernel)\n");
    } else {
        AkibaOS::Terminal::print_string("error - expected 1, got different value\n");
    }
    
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Green, 
                                 AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("System call tests completed.\n");
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, 
                                 AkibaOS::Terminal::Color::Black);
    
    /* Enter idle loop - kernel keeps running */
    AkibaOS::Terminal::print_string("Entering idle loop...\n");
    while (true) {
        __asm__ volatile("hlt");
    }
}