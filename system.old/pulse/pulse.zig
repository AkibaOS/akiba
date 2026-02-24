//! Pulse - Akiba OS Init System

const format = @import("format");
const kata = @import("kata");
const sys = @import("sys");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    // Spawn Shinigami - the zombie reaper
    _ = kata.spawn("/system/shinigami/shinigami.gen") catch {
        format.println("Pulse: FATAL - Failed to spawn Shinigami");
        return 1;
    };
    format.println("Pulse: Shinigami started");

    // Main shell loop
    while (true) {
        const shell_pid = kata.spawn("/system/ash/ash.gen") catch {
            format.println("Pulse: Failed to spawn shell");
            kata.yield();
            continue;
        };

        _ = kata.wait(shell_pid) catch {
            format.println("Pulse: Shell wait failed");
            kata.yield();
            continue;
        };

        format.println("\nPulse: Shell exited, respawning...\n");
    }

    return 0;
}
