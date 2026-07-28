//! Coverage Row Sink

pub const RowSink = struct {
    Context: *anyopaque,
    WriteRow: *const fn (context: *anyopaque, y: i32, x: i32, coverage: []const u8) void,
};
