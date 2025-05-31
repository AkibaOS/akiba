/*
 * System Timer Implementation
 *
 * This module implements the Programmable Interval Timer (PIT) driver
 * which provides the system heartbeat for timing and multitasking.
 *
 * The PIT is configured to generate interrupts every 1 millisecond,
 * providing precise timing for the operating system.
 */

#include <arch/timer.hpp>
#include <arch/idt.hpp>
#include <core/terminal.hpp>

namespace AkibaOS
{
    namespace Timer
    {
        /* System time tracking variables */
        volatile uint64_t system_tick_count = 0;
        volatile uint64_t milliseconds_since_boot = 0;

        /*
         * Port I/O functions for communicating with hardware
         *
         * These functions provide a safe interface to the x86 I/O ports
         * used by the PIT and other hardware devices.
         */

        /*
         * Write a byte to an I/O port
         *
         * @param port The I/O port number
         * @param value The byte value to write
         */
        inline void outb(uint16_t port, uint8_t value)
        {
            __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
        }

        /*
         * Read a byte from an I/O port
         *
         * @param port The I/O port number
         * @return The byte value read from the port
         */
        inline uint8_t inb(uint16_t port)
        {
            uint8_t value;
            __asm__ volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
            return value;
        }

        extern "C" void timer_interrupt_wrapper();

        /*
         * Timer interrupt handler
         *
         * This function is called every millisecond when the PIT generates
         * an interrupt. It updates system timing information and can be
         * extended later to handle scheduling and other time-based operations.
         */
        extern "C" void timer_interrupt_handler()
        {
            /* Increment our timing counters */
            system_tick_count++;
            milliseconds_since_boot++;

            /* 
             * Send End of Interrupt (EOI) signal to the PIC
             * This tells the interrupt controller that we've finished
             * handling this interrupt and it can send more.
             */
            outb(0x20, 0x20);  /* Send EOI to master PIC */

            /*
             * Optional: Display a dot every second to show timer is working
             * We'll comment this out after testing to avoid spam
             */
            /*
            if (milliseconds_since_boot % 1000 == 0) {
                Terminal::print_char('.');
            }
            */
        }

        /*
         * Configure the Programmable Interval Timer
         *
         * This function programs the PIT to generate interrupts at the
         * desired frequency (1000 Hz = 1ms intervals).
         */
        void configure_pit()
        {
            /*
             * Calculate the divisor for our target frequency
             * PIT frequency = PIT_BASE_FREQUENCY / divisor
             * For 1000 Hz: divisor = 1193182 / 1000 = 1193
             */
            uint16_t divisor = PIT_DIVISOR;

            /*
             * Send the command byte to configure the PIT
             * - Channel 0 (system timer)
             * - Access mode: low byte then high byte
             * - Mode 3: square wave generator (most compatible)
             * - Binary mode (not BCD)
             */
            uint8_t command = PITCommand::CHANNEL_0 | 
                             PITCommand::ACCESS_LOW_HIGH | 
                             PITCommand::MODE_3 | 
                             PITCommand::BINARY_MODE;
            
            outb(PIT_COMMAND, command);

            /*
             * Send the divisor value to channel 0
             * Must send low byte first, then high byte
             */
            outb(PIT_CHANNEL_0, divisor & 0xFF);        /* Low byte */
            outb(PIT_CHANNEL_0, (divisor >> 8) & 0xFF); /* High byte */
        }

        /*
         * Configure the Programmable Interrupt Controller (PIC)
         *
         * The PIC routes hardware interrupts to the CPU. We need to
         * configure it to properly handle timer interrupts.
         */
        void configure_pic()
        {
            /*
             * Remap the PIC interrupts to avoid conflicts with CPU exceptions
             * Master PIC: interrupts 32-39 (was 0-7)
             * Slave PIC:  interrupts 40-47 (was 8-15)
             */

            /* Save current interrupt masks */
            uint8_t master_mask = inb(0x21);
            uint8_t slave_mask = inb(0xA1);

            /* Start initialization sequence */
            outb(0x20, 0x11);  /* Master PIC: ICW1 - Initialize */
            outb(0xA0, 0x11);  /* Slave PIC:  ICW1 - Initialize */

            /* Set interrupt vector offsets */
            outb(0x21, 0x20);  /* Master PIC: ICW2 - IRQ 0-7 → interrupts 32-39 */
            outb(0xA1, 0x28);  /* Slave PIC:  ICW2 - IRQ 8-15 → interrupts 40-47 */

            /* Configure PIC cascade */
            outb(0x21, 0x04);  /* Master PIC: ICW3 - Slave on IRQ 2 */
            outb(0xA1, 0x02);  /* Slave PIC:  ICW3 - Cascade identity */

            /* Set 8086 mode */
            outb(0x21, 0x01);  /* Master PIC: ICW4 - 8086 mode */
            outb(0xA1, 0x01);  /* Slave PIC:  ICW4 - 8086 mode */

            /* Restore interrupt masks, but enable timer (IRQ 0) */
            outb(0x21, master_mask & ~0x01);  /* Enable IRQ 0 (timer) */
            outb(0xA1, slave_mask);
        }

        /*
         * Initialize the timer system
         *
         * This function sets up everything needed for system timing:
         * - Configures the PIC for proper interrupt routing
         * - Programs the PIT for 1000 Hz interrupts
         * - Sets up the interrupt handler
         * - Enables timer interrupts
         */
        void initialize()
        {
            Terminal::set_color(Terminal::Color::Yellow, Terminal::Color::Black);
            Terminal::print_string("Initializing system timer...\n");

            /* Configure interrupt controller */
            configure_pic();

            /* Set up timer interrupt handler in IDT */
            IDT::set_handler(32, reinterpret_cast<uint64_t>(timer_interrupt_wrapper), 
                                IDT::GateType::INTERRUPT_GATE);

            /* Configure the PIT for 1000 Hz operation */
            configure_pit();

            /* Reset timing variables */
            system_tick_count = 0;
            milliseconds_since_boot = 0;

            Terminal::set_color(Terminal::Color::Green, Terminal::Color::Black);
            Terminal::print_string("Timer initialized - 1000 Hz system clock active\n");
            Terminal::set_color(Terminal::Color::White, Terminal::Color::Black);
        }

        /*
         * Get system uptime in milliseconds
         *
         * @return Number of milliseconds since system boot
         */
        uint64_t get_uptime_ms()
        {
            return milliseconds_since_boot;
        }

        /*
         * Get system uptime in seconds
         *
         * @return Number of seconds since system boot
         */
        uint64_t get_uptime_seconds()
        {
            return milliseconds_since_boot / 1000;
        }

        /*
         * Simple delay function
         *
         * Blocks execution for the specified number of milliseconds.
         * This uses a busy-wait loop checking the system timer.
         *
         * @param milliseconds Number of milliseconds to wait
         */
        void delay_ms(uint32_t milliseconds)
        {
            uint64_t start_time = get_uptime_ms();
            uint64_t target_time = start_time + milliseconds;

            /* Busy wait until enough time has passed */
            while (get_uptime_ms() < target_time) {
                /* Yield to other processes when we implement scheduling */
                __asm__ volatile("pause");  /* Hint to CPU that we're spinning */
            }
        }
    }
}