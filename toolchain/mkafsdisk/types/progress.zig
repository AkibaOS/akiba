//! Disk Packing Unit Progress

const std = @import("std");

pub const Observer = struct {
    Context: ?*anyopaque,
    UpdateFn: *const fn (?*anyopaque, u32, u32) anyerror!void,

    pub fn update(self: Observer, written: u32, total: u32) !void {
        try self.UpdateFn(self.Context, written, total);
    }
};

pub const Record = struct {
    Written: u32,
    Total: u32,

    pub const BYTES = 2 * @sizeOf(u32);

    pub fn encode(self: Record) [BYTES]u8 {
        var bytes: [BYTES]u8 = undefined;
        std.mem.writeInt(u32, bytes[0..@sizeOf(u32)], self.Written, .little);
        std.mem.writeInt(u32, bytes[@sizeOf(u32)..], self.Total, .little);
        return bytes;
    }

    pub fn decode(bytes: *const [BYTES]u8) Record {
        return .{
            .Written = std.mem.readInt(u32, bytes[0..@sizeOf(u32)], .little),
            .Total = std.mem.readInt(u32, bytes[@sizeOf(u32)..], .little),
        };
    }

    pub fn follows(self: Record, previous: ?Record) bool {
        if (self.Total == 0 or self.Written > self.Total) return false;
        const last = previous orelse return self.Written == 0;
        return self.Total == last.Total and last.Written < last.Total and self.Written == last.Written + 1;
    }
};
