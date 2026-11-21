//! One Unpublished Child Bound To A Launch Request

const Kata = @import("mirai").kata.types.kata.Kata;
const Template = @import("mirai").launch.types.template.Template;

pub const Transaction = struct {
    Child: ?*Kata,
    Server: *Kata,
    Attached: bool = false,
    LoadingPages: u64 = 0,
    Pending: ?*Template = null,
};
