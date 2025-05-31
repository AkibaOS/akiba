/*
 * System Call Implementation
 *
 * This module implements the system call interface for AkibaOS Mirai.
 * It handles the translation between user program requests and kernel
 * services, providing a secure interface for system operations.
 */

#include <core/syscalls.hpp>
#include <core/terminal.hpp>
#include <core/memory.hpp>
#include <arch/idt.hpp>

namespace AkibaOS
{
    namespace SystemCalls
    {
        /*
         * External assembly function
         */
        extern "C" void system_call_wrapper();

        /*
         * Process management state
         */
        static int current_process_id = 1;
        static uintptr_t current_program_break = 0x400000;

        /*
         * Write data to a file descriptor
         */
        int64_t sys_write(int fd, const void* buffer, size_t count)
        {
            /* Parameter validation */
            if (buffer == nullptr) {
                return ERROR_INVALID_BUFFER;
            }

            if (count == 0) {
                return 0; /* Writing 0 bytes is success */
            }

            /* Only support stdout and stderr */
            if (fd != STDOUT && fd != STDERR) {
                return ERROR_INVALID_FD;
            }

            /* Write each character to the terminal */
            const char* char_buffer = static_cast<const char*>(buffer);
            for (size_t i = 0; i < count; i++) {
                Terminal::print_char(char_buffer[i]);
            }

            /* Return number of bytes written */
            return static_cast<int64_t>(count);
        }

        /*
         * Read data from a file descriptor
         */
        int64_t sys_read(int fd, void* buffer, size_t count)
        {   
            (void) fd;       /* Unused for now */
            (void) buffer;   /* Unused for now */
            (void) count;    /* Unused for now */
            /* Not implemented yet */
            return ERROR_NOT_IMPLEMENTED;
        }

        /*
         * Terminate the current process
         */
        [[noreturn]] void sys_exit(int status)
        {
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("\nProcess exited with status: ");
            
            if (status == 0) {
                Terminal::print_string("0 (success)\n");
            } else {
                Terminal::print_string("non-zero (error)\n");
            }
            
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
            Terminal::print_string("Returning to kernel...\n");

            /* Halt the system for now */
            while (true) {
                __asm__ volatile("hlt");
            }
        }

        /*
         * Get the current process ID
         */
        int64_t sys_getpid()
        {
            return static_cast<int64_t>(current_process_id);
        }

        /*
         * Change program break
         */
        int64_t sys_brk(intptr_t increment)
        {
            if (increment == 0) {
                return static_cast<int64_t>(current_program_break);
            }

            uintptr_t new_break = current_program_break + increment;
            
            if (new_break < 0x400000 || new_break > 0x800000) {
                return ERROR_NO_MEMORY;
            }

            current_program_break = new_break;
            return static_cast<int64_t>(new_break);
        }

        /*
         * System call dispatcher
         *
         * This function receives the saved CPU context and dispatches
         * to the appropriate system call handler.
         */
        extern "C" void system_call_handler(SystemCallContext* context)
        {
            /* Extract system call number and arguments from context */
            uint64_t syscall_number = context->rax;
            uint64_t arg1 = context->rdi;  /* First argument */
            uint64_t arg2 = context->rsi;  /* Second argument */
            uint64_t arg3 = context->rdx;  /* Third argument */
            
            int64_t result = ERROR_INVALID_SYSCALL;

            /* Dispatch based on system call number */
            switch (static_cast<SystemCallNumber>(syscall_number)) {
                case SYS_WRITE:
                    result = sys_write(static_cast<int>(arg1), 
                                     reinterpret_cast<const void*>(arg2), 
                                     static_cast<size_t>(arg3));
                    break;

                case SYS_READ:
                    result = sys_read(static_cast<int>(arg1), 
                                    reinterpret_cast<void*>(arg2), 
                                    static_cast<size_t>(arg3));
                    break;

                case SYS_EXIT:
                    sys_exit(static_cast<int>(arg1));
                    /* This function does not return */
                    break;

                case SYS_GETPID:
                    result = sys_getpid();
                    break;

                case SYS_BRK:
                    result = sys_brk(static_cast<intptr_t>(arg1));
                    break;

                default:
                    result = ERROR_INVALID_SYSCALL;
                    break;
            }

            /* Store the result in RAX for return to user program */
            context->rax = static_cast<uint64_t>(result);
        }

        /*
         * Initialize the system call interface
         */
        void initialize()
        {
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Initializing system call interface...\n");

            /* Install INT 0x80 handler */
            IDT::set_handler(0x80, reinterpret_cast<uint64_t>(system_call_wrapper), 
                           IDT::GateType::USER_INTERRUPT_GATE);

            Terminal::set_color(Terminal::Color::Green, Terminal::Color::Black);
            Terminal::print_string("System calls initialized (INT 0x80)\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
        }
    }
}