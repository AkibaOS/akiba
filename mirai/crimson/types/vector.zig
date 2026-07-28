//! Vector Mapping Type

const kind = @import("mirai").crimson.types.kind;

pub const Vector = struct {
    Number: u8,
    ExceptionType: kind.ExceptionType,
    HasErrorCode: bool,
    Name: []const u8,
};
