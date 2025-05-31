/*
 * Interrupt Descriptor Table (IDT) Implementation
 *
 * Enhanced with detailed exception handling for better debugging
 * and system stability. Each exception now provides specific
 * information about what went wrong and where.
 */

#include <arch/idt.hpp>
#include <core/terminal.hpp>

namespace AkibaOS
{
    namespace IDT
    {
        /* Array to hold the 256 possible IDT entries */
        Entry entries[256];

        /* IDT pointer structure that will be loaded into the IDTR register */
        Pointer pointer;

        /* External assembly functions */
        extern "C" void load_idt(Pointer* idt_pointer);
        extern "C" void exception_handler_wrapper();
        extern "C" void interrupt_handler_wrapper();

        /*
         * Display a 64-bit hexadecimal number
         *
         * Helper function to display memory addresses and register values
         * in a readable hexadecimal format.
         *
         * @param value The 64-bit value to display
         */
        void print_hex64(uint64_t value)
        {
            Terminal::print_string("0x");
            const char hex_chars[] = "0123456789ABCDEF";
            
            /* Display each nibble (4 bits) as a hex digit */
            for (int i = 60; i >= 0; i -= 4) {
                char hex_digit = hex_chars[(value >> i) & 0xF];
                Terminal::print_char(hex_digit);
            }
        }

        /*
         * Enhanced exception handler with detailed debugging information
         *
         * This function provides comprehensive information about exceptions,
         * including the exception type, CPU state, and memory addresses.
         * This makes debugging much easier when things go wrong.
         *
         * @param frame Pointer to exception frame containing CPU state
         */
        extern "C" void exception_handler(ExceptionFrame* frame)
        {
            /* Clear screen and display exception information */
            Terminal::clear();
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Red);
            Terminal::print_string("=== AKIBAOS MIRAI KERNEL PANIC ===\n");
            
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Exception: ");
            Terminal::set_color(Terminal::Color::Red, Terminal::Color::Black);
            
            /* Display exception name if it's a known exception */
            if (frame->exception_number < 32) {
                Terminal::print_string(EXCEPTION_NAMES[frame->exception_number]);
            } else {
                Terminal::print_string("Unknown Exception");
            }
            
            Terminal::print_string(" (");
            print_hex64(frame->exception_number);
            Terminal::print_string(")\n");

            /* Display error code if present */
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Error Code: ");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
            print_hex64(frame->error_code);
            Terminal::print_string("\n");

            /* Display instruction pointer where exception occurred */
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Instruction Pointer: ");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
            print_hex64(frame->rip);
            Terminal::print_string("\n");

            /* Display CPU flags */
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("CPU Flags: ");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
            print_hex64(frame->rflags);
            Terminal::print_string("\n\n");

            /* Display general-purpose registers */
            Terminal::set_color(Terminal::Color::Cyan, Terminal::Color::Black);
            Terminal::print_string("=== CPU REGISTERS ===\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
            
            Terminal::print_string("RAX: "); print_hex64(frame->rax); Terminal::print_string("  ");
            Terminal::print_string("RBX: "); print_hex64(frame->rbx); Terminal::print_string("\n");
            Terminal::print_string("RCX: "); print_hex64(frame->rcx); Terminal::print_string("  ");
            Terminal::print_string("RDX: "); print_hex64(frame->rdx); Terminal::print_string("\n");
            Terminal::print_string("RSI: "); print_hex64(frame->rsi); Terminal::print_string("  ");
            Terminal::print_string("RDI: "); print_hex64(frame->rdi); Terminal::print_string("\n");
            Terminal::print_string("RBP: "); print_hex64(frame->rbp); Terminal::print_string("  ");
            Terminal::print_string("RSP: "); print_hex64(frame->rsp); Terminal::print_string("\n");
            Terminal::print_string("R8:  "); print_hex64(frame->r8);  Terminal::print_string("  ");
            Terminal::print_string("R9:  "); print_hex64(frame->r9);  Terminal::print_string("\n");
            Terminal::print_string("R10: "); print_hex64(frame->r10); Terminal::print_string("  ");
            Terminal::print_string("R11: "); print_hex64(frame->r11); Terminal::print_string("\n");
            Terminal::print_string("R12: "); print_hex64(frame->r12); Terminal::print_string("  ");
            Terminal::print_string("R13: "); print_hex64(frame->r13); Terminal::print_string("\n");
            Terminal::print_string("R14: "); print_hex64(frame->r14); Terminal::print_string("  ");
            Terminal::print_string("R15: "); print_hex64(frame->r15); Terminal::print_string("\n");

            Terminal::print_string("\n");
            Terminal::set_color(Terminal::Color::Red, Terminal::Color::Black);
            Terminal::print_string("System halted. Press reset to restart.\n");

            /* Disable interrupts and halt */
            __asm__ volatile("cli; hlt");
            while (true) {
                __asm__ volatile("hlt");
            }
        }

        /*
         * Generic interrupt handler for non-exception interrupts
         *
         * @param interrupt_number The interrupt vector that was triggered
         */
        extern "C" void interrupt_handler(uint64_t interrupt_number)
        {
            Terminal::set_color(Terminal::Color::Green, Terminal::Color::Black);
            Terminal::print_string("Interrupt received: 0x");
            
            const char hex_chars[] = "0123456789ABCDEF";
            char hex_str[3];
            hex_str[0] = hex_chars[(interrupt_number >> 4) & 0xF];
            hex_str[1] = hex_chars[interrupt_number & 0xF];
            hex_str[2] = '\0';
            Terminal::print_string(hex_str);
            Terminal::print_string("\n");

            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
        }

        /*
         * Configure a single IDT entry
         */
        void set_handler(uint8_t index, uint64_t handler, GateType gate_type)
        {
            entries[index].offset_low = handler & 0xFFFF;
            entries[index].offset_middle = (handler >> 16) & 0xFFFF;
            entries[index].offset_high = (handler >> 32) & 0xFFFFFFFF;

            entries[index].selector = 0x08;  /* Kernel code segment */
            entries[index].ist = 0;
            entries[index].type_attributes = gate_type;
            entries[index].reserved = 0;
        }

        /*
         * Initialize the Interrupt Descriptor Table
         */
        void initialize()
        {
            pointer.size = (sizeof(Entry) * 256) - 1;
            pointer.address = reinterpret_cast<uint64_t>(&entries);

            /* Set up exception handlers (0-31) */
            for (uint8_t i = 0; i < 32; i++) {
                set_handler(i, reinterpret_cast<uint64_t>(exception_handler_wrapper), 
                           INTERRUPT_GATE);
            }

            /* Set up regular interrupt handlers (32-255) */
            for (uint16_t i = 32; i < 256; i++) {
                set_handler(i, reinterpret_cast<uint64_t>(interrupt_handler_wrapper), 
                           INTERRUPT_GATE);
            }

            load_idt(&pointer);
            __asm__ volatile("sti");

            Terminal::set_color(Terminal::Color::Green, Terminal::Color::Black);
            Terminal::print_string("IDT initialized with exception and interrupt handlers\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
        }
    }
}