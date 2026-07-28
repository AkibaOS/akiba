//! Inspect Corpse

const context = @import("mirai").crimson.context;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Context = types.context.Context;
const Corpse = types.corpse.Corpse;

pub fn inspect(corpse: *const Corpse) void {
    if (!corpse.isValid()) {
        serial.write.printf(messages.CORPSE_INVALID, .{});
        return;
    }

    serial.write.printf(messages.CORPSE_HEADER, .{ corpse.KataId, corpse.ThreadId });
    serial.write.printf(messages.CORPSE_EXCEPTION, .{
        corpse.ExceptionType.name(),
        corpse.ExceptionCode,
        corpse.ExceptionSubcode,
    });

    if (corpse.FaultAddress != 0) {
        serial.write.printf(messages.CORPSE_FAULT_ADDRESS, .{corpse.FaultAddress});
    }

    serial.write.printf("\n", .{});
    context.dump.dumpContext(&corpse.Context);
}

pub fn getContext(corpse: *const Corpse) *const Context {
    return &corpse.Context;
}

pub fn getStackSnapshot(corpse: *const Corpse) []const u8 {
    if (corpse.StackSnapshotSize == 0) {
        return &[_]u8{};
    }
    return corpse.StackSnapshot[0..corpse.StackSnapshotSize];
}

pub fn getMemorySnapshot(corpse: *const Corpse) []const u8 {
    if (corpse.MemorySnapshotSize == 0) {
        return &[_]u8{};
    }
    return corpse.MemorySnapshot[0..corpse.MemorySnapshotSize];
}

pub fn getMemorySnapshotAddress(corpse: *const Corpse) u64 {
    return corpse.MemorySnapshotAddress;
}

pub fn getFaultAddress(corpse: *const Corpse) u64 {
    return corpse.FaultAddress;
}

pub fn getTimestamp(corpse: *const Corpse) u64 {
    return corpse.Timestamp;
}
