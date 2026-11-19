//! QEMU Test Only Scenario And Display Metadata

const std = @import("std");

const date = @import("tests").screen.date;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.scenario;
const labels = @import("tests").strings.scenario;
const phase = @import("tests").guest.support.phase;
const port = @import("asm").io.port;
const Scenario = @import("tests").types.scenario.Scenario;

var choice: ?Scenario = null;

pub fn selectEarly() Scenario {
    const scenario = choose();
    choice = scenario;
    return scenario;
}

pub fn selected() Scenario {
    return choice orelse @panic(labels.INVALID_PHASE);
}

fn choose() Scenario {
    var value: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    if (readValue(labels.PHASE_FILE, &value, true)) |flag| {
        if (!std.mem.eql(u8, flag, labels.PHASE_VALUE)) @panic(labels.INVALID_PHASE);
        return phase.select() orelse @panic(labels.INVALID_PHASE);
    }
    const text = readValue(labels.FILE, &value, true) orelse return .Standard;
    return std.meta.stringToEnum(Scenario, text) orelse @panic(labels.INVALID);
}

pub fn allowCancellation() bool {
    var value: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    const flag = readValue(labels.CANCEL_FILE, &value, false) orelse return false;
    return std.mem.eql(u8, flag, labels.PHASE_VALUE);
}

pub fn buildDate(destination: []u8) ?[]const u8 {
    const value = readValue(labels.BUILD_DATE_FILE, destination, false) orelse return null;
    return if (date.valid(value)) value else null;
}

fn readValue(file: []const u8, destination: []u8, comptime required_valid: bool) ?[]const u8 {
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
