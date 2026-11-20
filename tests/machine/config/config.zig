//! Test-Only QEMU Configuration Reads

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").machine.constants.config.directory;
const labels = @import("tests").phase.strings.scenario;
const port = @import("asm").io.port;

pub fn liveEnabled() bool {
    var buffer: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    const flag = readValue(labels.LIVE_FILE, &buffer, true) orelse return false;
    if (!std.mem.eql(u8, flag, labels.PHASE_VALUE)) @panic(labels.INVALID_PHASE);
    return true;
}

pub fn cancellationEnabled() bool {
    var buffer: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    const flag = readValue(labels.CANCEL_FILE, &buffer, false) orelse return false;
    return std.mem.eql(u8, flag, labels.PHASE_VALUE);
}

pub fn readValue(file: []const u8, destination: []u8, comptime required_valid: bool) ?[]const u8 {
    const flags = guard.acquire();
    defer guard.release(flags);
    port.writeWord(inputs.SELECT_PORT, inputs.SIGNATURE_SELECTOR);
    var signature: [inputs.SIGNATURE.len]u8 = undefined;
    read(&signature);
    if (!std.mem.eql(u8, &signature, &inputs.SIGNATURE)) return null;
    port.writeWord(inputs.SELECT_PORT, inputs.DIRECTORY_SELECTOR);
    var count_bytes: [@sizeOf(u32)]u8 = undefined;
    read(&count_bytes);
    const count = std.mem.readInt(u32, &count_bytes, .big);
    if (count > inputs.MAX_FILES) {
        if (required_valid) @panic(labels.INVALID);
        return null;
    }
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        var entry: [inputs.ENTRY_BYTES]u8 = undefined;
        read(&entry);
        const name = std.mem.sliceTo(entry[inputs.NAME_OFFSET..], 0);
        if (!std.mem.eql(u8, name, file)) continue;
        const size = std.mem.readInt(u32, entry[0..4], .big);
        const selector = std.mem.readInt(u16, entry[4..6], .big);
        if (size == 0 or size > destination.len) {
            if (required_valid) @panic(labels.INVALID);
            return null;
        }
        port.writeWord(inputs.SELECT_PORT, selector);
        const text = destination[0..size];
        read(text);
        return std.mem.trimEnd(u8, text, &.{0});
    }
    return null;
}

fn read(destination: []u8) void {
    for (destination) |*byte| byte.* = port.readByte(inputs.DATA_PORT);
}
