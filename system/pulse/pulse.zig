//! Pulse - Akiba OS Init System
//! First Kata to run (PID 1), manages system lifecycle

const akiba = @import("akiba");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    // Init loop - respawn shell when it exits
    while (true) {
        const shell_pid = akiba.kata.spawn("/system/ash/ash.akiba") catch {
            akiba.io.println("Pulse: Failed to spawn shell") catch {};
            akiba.kata.yield();
            continue;
        };

        // Wait for shell to exit
        _ = akiba.kata.wait(shell_pid) catch {
            akiba.io.println("Pulse: Shell wait failed") catch {};
            akiba.kata.yield();
            continue;
        };

        // Shell exited, respawn
        akiba.io.println("\nPulse: Shell exited, respawning...\n") catch {};
    }

    return 0;
}
