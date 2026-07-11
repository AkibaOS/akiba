//! Hikari Console Output Helper

const efi = @import("../efi/efi.zig");

pub fn print(console: *efi.protocols.SimpleTextOutputProtocol, msg: []const u8) void {
    for (msg) |character| {
        var buffer = [2:0]u16{ character, 0 };
        _ = console.output_string(console, &buffer);
    }
}
