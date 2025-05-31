/*
 * Interrupt Descriptor Table (IDT) Header
 *
 * Enhanced with specific exception handling capabilities for better
 * system stability and debugging information.
 */

#pragma once

#include <cstdint>

namespace AkibaOS
{
    namespace IDT
    {
        /*
         * CPU Exception Information Structure
         *
         * This structure holds information about a CPU exception,
         * including the exception type and the CPU state when it occurred.
         */
        struct ExceptionFrame
        {
            /* CPU state at time of exception */
            uint64_t r15, r14, r13, r12, r11, r10, r9, r8;
            uint64_t rdi, rsi, rbp, rdx, rcx, rbx, rax;
            
            /* Exception information */
            uint64_t exception_number;
            uint64_t error_code;        /* Some exceptions provide an error code */
            
            /* CPU-pushed information (in this order) */
            uint64_t rip;               /* Instruction pointer where exception occurred */
            uint64_t cs;                /* Code segment */
            uint64_t rflags;            /* CPU flags register */
            uint64_t rsp;               /* Stack pointer */
            uint64_t ss;                /* Stack segment */
        };

        /*
         * Exception Names for Display
         *
         * Human-readable names for the first 32 CPU exceptions.
         */
        const char* const EXCEPTION_NAMES[] = {
            "Division by Zero",
            "Debug",
            "Non-Maskable Interrupt", 
            "Breakpoint",
            "Overflow",
            "Bound Range Exceeded",
            "Invalid Opcode",
            "Device Not Available",
            "Double Fault",
            "Coprocessor Segment Overrun",
            "Invalid TSS",
            "Segment Not Present",
            "Stack Segment Fault",
            "General Protection Fault",
            "Page Fault",
            "Reserved",
            "x87 Floating Point Exception",
            "Alignment Check",
            "Machine Check",
            "SIMD Floating Point Exception",
            "Virtualization Exception",
            "Reserved", "Reserved", "Reserved", "Reserved", "Reserved",
            "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved"
        };

        /* Previous declarations remain the same... */
        struct Entry
        {
            uint16_t offset_low;
            uint16_t selector;
            uint8_t ist;
            uint8_t type_attributes;
            uint16_t offset_middle;
            uint32_t offset_high;
            uint32_t reserved;
        } __attribute__((packed));

        struct Pointer
        {
            uint16_t size;
            uint64_t address;
        } __attribute__((packed));

        enum GateType : uint8_t
        {
            INTERRUPT_GATE = 0x8E,
            TRAP_GATE = 0x8F,
            USER_INTERRUPT_GATE = 0xEE
        };

        enum Interrupts : uint8_t
        {
            DIVIDE_BY_ZERO = 0,
            DEBUG = 1,
            NON_MASKABLE_INTERRUPT = 2,
            BREAKPOINT = 3,
            OVERFLOW = 4,
            BOUND_RANGE_EXCEEDED = 5,
            INVALID_OPCODE = 6,
            DEVICE_NOT_AVAILABLE = 7,
            DOUBLE_FAULT = 8,
            COPROCESSOR_SEGMENT_OVERRUN = 9,
            INVALID_TSS = 10,
            SEGMENT_NOT_PRESENT = 11,
            STACK_SEGMENT_FAULT = 12,
            GENERAL_PROTECTION_FAULT = 13,
            PAGE_FAULT = 14,
            X87_FLOATING_POINT_EXCEPTION = 16,
            ALIGNMENT_CHECK = 17,
            MACHINE_CHECK = 18,
            SIMD_FLOATING_POINT_EXCEPTION = 19,
            VIRTUALIZATION_EXCEPTION = 20,
            
            TIMER_INTERRUPT = 32,
            KEYBOARD_INTERRUPT = 33
        };

        void initialize();
        void set_handler(uint8_t interrupt_number, uint64_t handler, GateType gate_type);
        
        /*
         * Exception handler that provides detailed debugging information
         *
         * @param frame Pointer to exception frame with CPU state and exception info
         */
        extern "C" void exception_handler(ExceptionFrame* frame);
    }
}