//! Inspect Corpse

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const context_ops = @import("../context/context.zig");
const messages = @import("../strings/strings.zig").messages;

const Corpse = types.Corpse;
const Context = types.Context;

pub fn inspect(corpse: *const Corpse) void {
    if (!corpse.is_valid()) {
        serial.printf(messages.corpse_invalid, .{});
        return;
    }

    serial.printf(messages.corpse_header, .{ corpse.kata_id, corpse.thread_id });
    serial.printf(messages.corpse_exception, .{
        corpse.exception_type.name(),
        corpse.exception_code,
        corpse.exception_subcode,
    });

    if (corpse.fault_address != 0) {
        serial.printf(messages.corpse_fault_address, .{corpse.fault_address});
    }

    serial.printf("\n", .{});
    context_ops.dump_context(&corpse.context);
}

pub fn get_context(corpse: *const Corpse) *const Context {
    return &corpse.context;
}

pub fn get_stack_snapshot(corpse: *const Corpse) []const u8 {
    if (corpse.stack_snapshot_size == 0) {
        return &[_]u8{};
    }
    return corpse.stack_snapshot[0..corpse.stack_snapshot_size];
}

pub fn get_memory_snapshot(corpse: *const Corpse) []const u8 {
    if (corpse.memory_snapshot_size == 0) {
        return &[_]u8{};
    }
    return corpse.memory_snapshot[0..corpse.memory_snapshot_size];
}

pub fn get_memory_snapshot_address(corpse: *const Corpse) u64 {
    return corpse.memory_snapshot_address;
}

pub fn get_fault_address(corpse: *const Corpse) u64 {
    return corpse.fault_address;
}

pub fn get_timestamp(corpse: *const Corpse) u64 {
    return corpse.timestamp;
}
