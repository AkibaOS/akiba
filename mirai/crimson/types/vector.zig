//! Vector Mapping Type

const kind = @import("kind.zig");

pub const Vector = struct {
    Number: u8,
    ExceptionType: kind.ExceptionType,
    HasErrorCode: bool,
    Name: []const u8,
};
