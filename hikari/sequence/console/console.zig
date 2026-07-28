//! Hikari Console Output Helper

const efi = @import("hikari").efi;

const ASCII_CARRIAGE_RETURN: u8 = 0x0D;
const ASCII_LINE_FEED: u8 = 0x0A;

pub fn print(console: *efi.protocols.output.SimpleTextOutputProtocol, message: []const u8) void {
    for (message) |character| {
        writeCharacter(console, character);
    }
    writeCharacter(console, ASCII_CARRIAGE_RETURN);
    writeCharacter(console, ASCII_LINE_FEED);
}

fn writeCharacter(console: *efi.protocols.output.SimpleTextOutputProtocol, character: u8) void {
    var buffer = [2:0]u16{ character, 0 };
    _ = console.OutputString(console, &buffer);
}
