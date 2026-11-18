//! Coverage Row Sink

pub const Clip = struct {
    Left: i64 = 0,
    Top: i64 = 0,
    Right: i64,
    Bottom: i64,
};

pub const RowSink = struct {
    Clip: Clip,
    Context: *anyopaque,
    WriteRow: *const fn (context: *anyopaque, y: i32, x: i32, coverage: []const u8) void,
};
