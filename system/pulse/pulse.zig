//! Pulse - Akiba OS Init System
//! First Kata to run (PID 1), manages system lifecycle

const akiba = @import("akiba");

export fn _start() noreturn {
    akiba.io.println("Pulse: System ready!") catch {};

    while (true) {
        akiba.kata.yield();
    }
}
