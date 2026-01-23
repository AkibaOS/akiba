//! Cast command - Execute .akiba binaries
//! Cast = Execute (matching our AI Table invocation naming)

const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const hikari = @import("../../hikari/loader.zig");
const serial = @import("../../drivers/serial.zig");
const terminal = @import("../../terminal.zig");

pub fn execute(fs: *afs.AFS(ahci.BlockDevice), args: []const []const u8) void {
    if (args.len == 0) {
        terminal.print("Usage: cast <binary>\n");
        terminal.print("Example: cast /binaries/hello.akiba\n");
        return;
    }

    const binary_path = args[0];

    terminal.print("Casting ");
    terminal.print(binary_path);
    terminal.print("...\n");

    // Load and execute the program
    const kata_id = hikari.load_program(fs, binary_path) catch |err| {
        terminal.print("Error: Failed to cast binary\n");
        _ = err;
        return;
    };

    terminal.print("Kata cast successfully (ID: ");
    print_decimal(kata_id);
    terminal.print(")\n");
    terminal.print("(Program is now running in background)\n");
}

fn print_decimal(value: u32) void {
    if (value == 0) {
        terminal.print("0");
        return;
    }

    var buf: [16]u8 = undefined;
    var i: usize = 0;
    var n = value;

    while (n > 0) : (i += 1) {
        buf[i] = @intCast('0' + (n % 10));
        n /= 10;
    }

    // Reverse print
    while (i > 0) {
        i -= 1;
        terminal.put_char(buf[i]);
    }
}
