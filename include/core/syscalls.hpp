/*
 * System Call Interface Header
 *
 * This module defines the system call interface for AkibaOS Mirai.
 * System calls provide a secure way for user programs to request
 * kernel services while maintaining proper privilege separation.
 */

#pragma once

#include <cstdint>
#include <cstddef>

namespace AkibaOS
{
    namespace SystemCalls
    {
        /*
         * System Call Numbers
         */
        enum SystemCallNumber : uint64_t
        {
            SYS_EXIT = 1,       /* Terminate current process */
            SYS_WRITE = 2,      /* Write data to file descriptor */
            SYS_READ = 3,       /* Read data from file descriptor */
            SYS_GETPID = 4,     /* Get process ID */
            SYS_BRK = 5,        /* Change data segment size */
            SYS_MMAP = 6,       /* Map memory */
            SYS_MUNMAP = 7,     /* Unmap memory */
            SYS_FORK = 8,       /* Create new process */
            SYS_EXEC = 9,       /* Execute program */
            SYS_WAIT = 10       /* Wait for child process */
        };

        /*
         * Standard File Descriptors
         */
        enum StandardFileDescriptor : int
        {
            STDIN = 0,          /* Standard input */
            STDOUT = 1,         /* Standard output */
            STDERR = 2          /* Standard error */
        };

        /*
         * System Call Result Codes
         */
        enum SystemCallResult : int64_t
        {
            SUCCESS = 0,
            ERROR_INVALID_SYSCALL = -1,
            ERROR_INVALID_FD = -2,
            ERROR_INVALID_BUFFER = -3,
            ERROR_INVALID_COUNT = -4,
            ERROR_NO_MEMORY = -5,
            ERROR_PERMISSION = -6,
            ERROR_NOT_IMPLEMENTED = -99
        };

        /*
         * System Call Context Structure
         *
         * CRITICAL: The order of registers must match exactly how the 
         * assembly wrapper pushes them onto the stack!
         *
         * Assembly pushes: r15, r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rbp, rdx, rcx, rbx, rax
         * Stack layout:    [rax][rbx][rcx][rdx][rbp][rsi][rdi][r8][r9][r10][r11][r12][r13][r14][r15]
         *                   ^-- struct pointer points here
         */
        struct SystemCallContext
        {
            /* Registers in the order they appear on the stack (rax is at lowest address) */
            uint64_t rax;       /* System call number / return value */
            uint64_t rbx;
            uint64_t rcx;
            uint64_t rdx;       /* Third argument */
            uint64_t rbp;
            uint64_t rsi;       /* Second argument */
            uint64_t rdi;       /* First argument */
            uint64_t r8;
            uint64_t r9;
            uint64_t r10;
            uint64_t r11;
            uint64_t r12;
            uint64_t r13;
            uint64_t r14;
            uint64_t r15;
            
            /* CPU state (pushed by INT instruction) */
            uint64_t rip;       /* Return address */
            uint64_t cs;        /* Code segment */
            uint64_t rflags;    /* CPU flags */
            uint64_t rsp;       /* User stack pointer */
            uint64_t ss;        /* Stack segment */
        };

        /*
         * Function declarations
         */
        void initialize();
        extern "C" void system_call_handler(SystemCallContext* context);

        /*
         * Individual System Call Implementations
         */
        int64_t sys_write(int fd, const void* buffer, size_t count);
        int64_t sys_read(int fd, void* buffer, size_t count);
        [[noreturn]] void sys_exit(int status);
        int64_t sys_getpid();
        int64_t sys_brk(intptr_t increment);
    }
}