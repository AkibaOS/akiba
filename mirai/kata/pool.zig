//! Kata pool management

const attachment = @import("attachment.zig");
const attachment_const = @import("../common/constants/attachment.zig");
const kata_const = @import("../common/constants/kata.zig");
const kata_limits = @import("../common/limits/kata.zig");
const types = @import("types.zig");

pub var pool: [kata_limits.MAX_KATAS]types.Kata = undefined;
pub var used: [kata_limits.MAX_KATAS]bool = [_]bool{false} ** kata_limits.MAX_KATAS;
var next_id: u32 = 1;

pub fn init() void {
    for (&pool, 0..) |*kata, i| {
        kata.* = create_empty();
        used[i] = false;
    }
}

pub fn create() !*types.Kata {
    for (&pool, 0..) |*kata, i| {
        if (!used[i]) {
            used[i] = true;

            const kata_id = next_id;
            next_id += 1;

            kata.* = create_empty();
            kata.id = kata_id;
            kata.state = .Ready;

            kata.current_location[0] = '/';

            kata.attachments[0] = attachment.Attachment{
                .attachment_type = .Device,
                .device_type = .Source,
                .flags = attachment_const.VIEW_ONLY,
            };

            kata.attachments[1] = attachment.Attachment{
                .attachment_type = .Device,
                .device_type = .Stream,
                .flags = attachment_const.MARK_ONLY,
            };

            kata.attachments[2] = attachment.Attachment{
                .attachment_type = .Device,
                .device_type = .Trace,
                .flags = attachment_const.MARK_ONLY,
            };

            return kata;
        }
    }

    return error.TooManyKata;
}

pub fn get(id: u32) ?*types.Kata {
    for (&pool, 0..) |*kata, i| {
        if (used[i] and kata.id == id) {
            return kata;
        }
    }
    return null;
}

pub fn dissolve(kata_id: u32) void {
    const waker = @import("sensei/waker.zig");
    const memory = @import("memory.zig");

    for (&pool, 0..) |*kata, i| {
        if (used[i] and kata.id == kata_id) {
            // Clean up all memory associated with this Kata
            memory.cleanup(kata);

            kata.state = .Dissolved;
            used[i] = false;
            waker.wake_waiting(kata_id);
            return;
        }
    }
}

fn create_empty() types.Kata {
    return types.Kata{
        .id = 0,
        .state = .Dissolved,
        .context = types.Context.init(),
        .page_table = 0,
        .stack_top = 0,
        .user_stack_top = 0,
        .attachments = [_]attachment.Attachment{.{}} ** kata_limits.MAX_ATTACHMENTS,
        .current_location = undefined,
        .current_location_len = 1,
        .current_cluster = 0,
        .parent_id = 0,
        .letter_type = 0,
        .letter_data = undefined,
        .letter_len = 0,
        .vruntime = 0,
        .weight = kata_const.DEFAULT_WEIGHT,
        .last_run = 0,
        .next = null,
        .waiting_for = 0,
        .exit_code = 0,
    };
}
