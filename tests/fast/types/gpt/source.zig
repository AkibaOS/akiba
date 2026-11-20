//! Traced Native GPT Fixture Reads

const layout = @import("tests").fast.constants.gpt.layout;

const Disk = @import("tests").fast.types.gpt.disk.Disk;

pub const Source = struct {
    Disk: *const Disk,
    Calls: [layout.STREAM_READS]u64 = undefined,
    Count: usize = 0,
    FailAt: ?u64 = null,
};
