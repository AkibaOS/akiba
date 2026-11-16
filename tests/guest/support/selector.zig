//! QEMU Test Only Scenario Selection

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.scenario;
const labels = @import("tests").strings.scenario;
const port = @import("asm").io.port;
const Scenario = @import("tests").types.scenario.Scenario;

pub fn selected() Scenario {
    const flags = guard.acquire();
    defer guard.release(flags);
    port.writeWord(inputs.SELECT_PORT, inputs.SIGNATURE_SELECTOR);
    var signature: [inputs.SIGNATURE.len]u8 = undefined;
    read(&signature);
    if (!std.mem.eql(u8, &signature, &inputs.SIGNATURE)) return .Standard;
    port.writeWord(inputs.SELECT_PORT, inputs.DIRECTORY_SELECTOR);
    var count_bytes: [@sizeOf(u32)]u8 = undefined;
    read(&count_bytes);
    const count = std.mem.readInt(u32, &count_bytes, .big);
    if (count > inputs.MAX_FILES) @panic(labels.INVALID);
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        var entry: [inputs.ENTRY_BYTES]u8 = undefined;
        read(&entry);
        const name = std.mem.sliceTo(entry[inputs.NAME_OFFSET..], 0);
        if (!std.mem.eql(u8, name, labels.FILE)) continue;
        const size = std.mem.readInt(u32, entry[0..4], .big);
        const selector = std.mem.readInt(u16, entry[4..6], .big);
        if (size == 0 or size > inputs.MAX_VALUE_BYTES) @panic(labels.INVALID);
        port.writeWord(inputs.SELECT_PORT, selector);
        var value: [inputs.MAX_VALUE_BYTES]u8 = undefined;
        const text = value[0..size];
        read(text);
        return std.meta.stringToEnum(Scenario, std.mem.trimEnd(u8, text, &.{0})) orelse @panic(labels.INVALID);
    }
    return .Standard;
}

fn read(destination: []u8) void {
    for (destination) |*byte| byte.* = port.readByte(inputs.DATA_PORT);
}
