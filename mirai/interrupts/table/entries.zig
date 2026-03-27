//! IDT Entries Table

const types = @import("../types/types.zig");

pub var entries: [256]types.Gate64 = [_]types.Gate64{types.Gate64.empty()} ** 256;
