//! Terminate Kata

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const corpse_ops = @import("../corpse/corpse.zig");
const messages = @import("../strings/strings.zig").messages;

const Exception = types.Exception;
const Corpse = types.Corpse;

pub fn terminate(exception: *const Exception) void {
    serial.printf(messages.terminate_kata_thread, .{
        exception.kata_id,
        exception.thread_id,
    });

    cleanup_thread(exception.thread_id);
    cleanup_kata_if_last(exception.kata_id);
}

pub fn terminate_with_corpse(exception: *const Exception) ?*Corpse {
    serial.printf(messages.terminate_kata_corpse, .{exception.kata_id});

    const corpse = corpse_ops.allocate();
    if (corpse) |c| {
        c.* = corpse_ops.generate(exception);
    }

    terminate(exception);

    return corpse;
}

fn cleanup_thread(thread_id: u64) void {
    _ = thread_id;
}

fn cleanup_kata_if_last(kata_id: u64) void {
    _ = kata_id;
}

pub fn is_last_thread(kata_id: u64) bool {
    _ = kata_id;
    return true;
}
