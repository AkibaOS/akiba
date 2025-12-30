//! Pulse - Akiba OS Init System
//! First Kata to run (PID 1), manages system lifecycle

const akiba = @import("akiba");

export fn _start() noreturn {
    // IMMEDIATE DEBUG - write directly to port to bypass everything
    asm volatile (
        \\mov $0x3F8, %dx
        \\mov $'P', %al
        \\out %al, %dx
        \\mov $'U', %al
        \\out %al, %dx
        \\mov $'L', %al
        \\out %al, %dx
        \\mov $'S', %al
        \\out %al, %dx
        \\mov $'E', %al
        \\out %al, %dx
        \\mov $'!', %al
        \\out %al, %dx
        \\mov $'\n', %al
        \\out %al, %dx
    );

    akiba.io.println("Pulse: Init system starting...") catch {};

    // Spawn echo as a test
    const child_pid = akiba.kata.spawn("/binaries/echo.akiba") catch {
        akiba.io.println("Pulse: Failed to spawn child") catch {};
        akiba.kata.exit(1);
    };

    akiba.io.println("Pulse: Spawned child process") catch {};

    // Wait for child to exit
    const exit_code = akiba.kata.wait(child_pid) catch {
        akiba.io.println("Pulse: Wait failed") catch {};
        akiba.kata.exit(1);
    };

    akiba.io.println("Pulse: Child process exited") catch {};

    // For now, just exit. Later: respawn shell or shutdown
    akiba.io.println("Pulse: Shutting down") catch {};
    akiba.kata.exit(exit_code);
}
