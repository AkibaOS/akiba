//! Loaded Module Info

const constants = @import("mirai").crimson.constants;

const limits = constants.limits;

pub const ModuleInfo = struct {
    Name: [limits.MODULE_NAME_CAPACITY]u8,
    NameLength: usize,
    BaseAddress: u64,
    Size: u64,
};
