//! Pulse - Akiba OS Init System

const format = @import("format");
const kata = @import("kata");
const sys = @import("sys");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    while (true) {
        const shell_pid = kata.spawn("/system/ash/ash.akiba") catch {
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
