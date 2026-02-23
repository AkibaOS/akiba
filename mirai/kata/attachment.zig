//! Attachment management

const attachment_limits = @import("../common/limits/attachment.zig");
const kata_limits = @import("../common/limits/kata.zig");

pub const Type = enum {
    Unit,
    Device,
    Closed,
};

pub const DeviceType = enum {
    Source,
    Stream,
    Trace,
    Void,
    Chaos,
    Zero,
    Console,
};

pub const Attachment = struct {
    attachment_type: Type = .Closed,

    location: [attachment_limits.MAX_LOCATION_LENGTH]u8 = undefined,
    location_len: usize = 0,
    position: u64 = 0,
    unit_size: u64 = 0,
    buffer: ?[]u8 = null,
    flags: u32 = 0,
    dirty: bool = false,

    device_type: ?DeviceType = null,
};

const POOL_SIZE = kata_limits.MAX_KATAS * kata_limits.MAX_ATTACHMENTS;
var pool: [POOL_SIZE]Attachment = undefined;
var pool_used: [POOL_SIZE]bool = [_]bool{false} ** POOL_SIZE;

pub fn alloc() ?*Attachment {
    for (&pool, 0..) |*entry, i| {
        if (!pool_used[i]) {
            pool_used[i] = true;
            entry.* = Attachment{};
            return entry;
        }
    }
    return null;
}

pub fn free(ptr: *Attachment) void {
    const addr = @intFromPtr(ptr);
    const base = @intFromPtr(&pool[0]);
    const size = @sizeOf(Attachment);
    if (addr >= base and addr < base + POOL_SIZE * size) {
        const idx = (addr - base) / size;
        pool_used[idx] = false;
    }
}
