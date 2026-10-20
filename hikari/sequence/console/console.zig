//! Hikari Console Output Helper

const constants = @import("hikari").sequence.constants.console;
const efi = @import("hikari").efi;

pub fn print(console: *efi.types.protocols.output.SimpleTextOutputProtocol, message: []const u8) void {
    for (message) |character| {
        writeCharacter(console, character);
    }
    writeCharacter(console, constants.ASCII_CARRIAGE_RETURN);
    writeCharacter(console, constants.ASCII_LINE_FEED);
}

fn writeCharacter(console: *efi.types.protocols.output.SimpleTextOutputProtocol, character: u8) void {
    var buffer = [2:0]u16{ character, 0 };
    _ = console.OutputString(console, &buffer);
}
