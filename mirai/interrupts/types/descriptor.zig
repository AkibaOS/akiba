//! IDT Descriptor for LIDT

const gate = @import("gate.zig");

pub const Descriptor = packed struct(u80) {
    limit: u16,
    base: u64,

    pub fn from_table(table: *const [256]gate.Gate64) Descriptor {
        return Descriptor{
            .limit = @sizeOf([256]gate.Gate64) - 1,
            .base = @intFromPtr(table),
        };
    }
};

comptime {
    if (@sizeOf(Descriptor) != 10) @compileError("Descriptor must be 10 bytes");
}
