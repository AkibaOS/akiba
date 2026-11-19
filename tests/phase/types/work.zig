//! Diagnostic Work Estimate And Verified Progress

const std = @import("std");

pub const Work = struct {
    Planned: u32,
    Verified: u32 = 0,

    pub fn addPlan(self: *Work, count: u32) void {
        self.Planned +|= count;
    }

    pub fn credit(self: *Work, count: u32) void {
        self.Verified +|= count;
        self.Planned = @max(self.Planned, self.Verified);
    }

    pub const BYTES = 2 * @sizeOf(u32);

    pub fn encode(self: Work) [BYTES]u8 {
        var bytes: [BYTES]u8 = undefined;
        std.mem.writeInt(u32, bytes[0..@sizeOf(u32)], self.Planned, .little);
        std.mem.writeInt(u32, bytes[@sizeOf(u32)..], self.Verified, .little);
        return bytes;
    }

    pub fn decode(bytes: *const [BYTES]u8) Work {
        return .{
            .Planned = std.mem.readInt(u32, bytes[0..@sizeOf(u32)], .little),
            .Verified = std.mem.readInt(u32, bytes[@sizeOf(u32)..], .little),
        };
    }

    pub fn valid(self: Work) bool {
        return self.Planned != 0 and self.Verified <= self.Planned;
    }
};
