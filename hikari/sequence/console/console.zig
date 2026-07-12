//! Hikari Console Output Helper

const efi = @import("../../efi/efi.zig");

pub fn print(console: *efi.protocols.output.SimpleTextOutputProtocol, message: []const u8) void {
    for (message) |character| {
        var buffer = [2:0]u16{ character, 0 };
        _ = console.OutputString(console, &buffer);
    }
}
