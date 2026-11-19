//! Crimson Regression Fixtures

const crimson = @import("mirai").crimson;

pub const VectorCase = struct {
    Number: u8,
    Kind: crimson.types.kind.ExceptionType,
    ErrorCode: bool,
};

pub const ActionCase = struct {
    Code: u64,
    Action: crimson.types.behavior.Action,
    Modify: bool,
};
