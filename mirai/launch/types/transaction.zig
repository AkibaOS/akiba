//! One Unpublished Child Bound To A Launch Request

const Kata = @import("mirai").kata.types.kata.Kata;

pub const Transaction = struct {
    Child: ?*Kata,
    LoadingPages: u64 = 0,
};
