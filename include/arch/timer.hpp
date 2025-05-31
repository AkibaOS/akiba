/*
 * System Timer Interface Header
 *
 * This module handles the Programmable Interval Timer (PIT) which provides
 * regular interrupts for system timing, multitasking, and scheduling.
 *
 * The PIT generates IRQ 0 (interrupt 32) at configurable intervals.
 * We configure it for 1000 Hz (1ms intervals) to provide precise timing
 * for scheduling and system operations.
 */

#pragma once

#include <cstdint>

namespace AkibaOS
{
    namespace Timer
    {
        /*
         * PIT Hardware Constants
         *
         * The PIT operates at a base frequency of 1,193,182 Hz.
         * We can divide this by a value to get different interrupt rates.
         */
        constexpr uint32_t PIT_BASE_FREQUENCY = 1193182;  /* PIT oscillator frequency */
        constexpr uint16_t TARGET_FREQUENCY = 1000;       /* Target: 1000 Hz (1ms intervals) */
        constexpr uint16_t PIT_DIVISOR = PIT_BASE_FREQUENCY / TARGET_FREQUENCY;

        /*
         * PIT I/O Ports
         *
         * The PIT uses these I/O ports for configuration and data transfer.
         */
        constexpr uint16_t PIT_CHANNEL_0 = 0x40;          /* Channel 0 data port */
        constexpr uint16_t PIT_CHANNEL_1 = 0x41;          /* Channel 1 data port (unused) */
        constexpr uint16_t PIT_CHANNEL_2 = 0x42;          /* Channel 2 data port (PC speaker) */
        constexpr uint16_t PIT_COMMAND = 0x43;            /* Command/mode register */

        /*
         * PIT Command Register Bits
         *
         * The command register configures how the PIT operates.
         * Each field controls different aspects of the timer behavior.
         */
        enum PITCommand : uint8_t
        {
            /* Channel Selection (bits 7-6) */
            CHANNEL_0 = 0x00,                             /* Select channel 0 */
            CHANNEL_1 = 0x40,                             /* Select channel 1 */
            CHANNEL_2 = 0x80,                             /* Select channel 2 */

            /* Access Mode (bits 5-4) */
            ACCESS_LATCH = 0x00,                          /* Latch current count */
            ACCESS_LOW_BYTE = 0x10,                       /* Access low byte only */
            ACCESS_HIGH_BYTE = 0x20,                      /* Access high byte only */
            ACCESS_LOW_HIGH = 0x30,                       /* Access low then high byte */

            /* Operating Mode (bits 3-1) */
            MODE_0 = 0x00,                                /* Interrupt on terminal count */
            MODE_1 = 0x02,                                /* Hardware retriggerable one-shot */
            MODE_2 = 0x04,                                /* Rate generator */
            MODE_3 = 0x06,                                /* Square wave generator */
            MODE_4 = 0x08,                                /* Software triggered strobe */
            MODE_5 = 0x0A,                                /* Hardware triggered strobe */

            /* BCD/Binary Mode (bit 0) */
            BINARY_MODE = 0x00,                           /* 16-bit binary counting */
            BCD_MODE = 0x01                               /* 4-digit BCD counting */
        };

        /*
         * System Time Tracking
         *
         * These variables track system uptime and provide timing services.
         */
        extern volatile uint64_t system_tick_count;       /* Total timer interrupts since boot */
        extern volatile uint64_t milliseconds_since_boot; /* System uptime in milliseconds */

        /*
         * Initialize the Programmable Interval Timer
         *
         * This function configures the PIT to generate interrupts at 1000 Hz
         * and sets up the interrupt handler for IRQ 0.
         */
        void initialize();

        /*
         * Timer interrupt handler
         *
         * This function is called every time the PIT generates an interrupt.
         * It updates system time and can trigger scheduling decisions.
         */
        extern "C" void timer_interrupt_handler();

        /*
         * Get system uptime in milliseconds
         *
         * @return Number of milliseconds since system boot
         */
        uint64_t get_uptime_ms();

        /*
         * Get system uptime in seconds
         *
         * @return Number of seconds since system boot
         */
        uint64_t get_uptime_seconds();

        /*
         * Simple delay function
         *
         * Blocks execution for the specified number of milliseconds.
         * This is a busy-wait implementation for now.
         *
         * @param milliseconds Number of milliseconds to wait
         */
        void delay_ms(uint32_t milliseconds);
    }
}