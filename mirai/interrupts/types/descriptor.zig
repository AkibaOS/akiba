//! IDT Descriptor for LIDT

const constants = @import("mirai").interrupts.constants;
const gate = @import("mirai").interrupts.types.gate;
const strings = @import("mirai").interrupts.strings.layout;

const IDT_ENTRIES = constants.idt.limits.IDT_ENTRIES;

pub const Descriptor = packed struct(u80) {
    Limit: u16,
    Base: u64,

    pub fn fromTable(table: *const [IDT_ENTRIES]gate.Gate64) Descriptor {
        return Descriptor{
            .Limit = @sizeOf([IDT_ENTRIES]gate.Gate64) - 1,
            .Base = @intFromPtr(table),
        };
    }
};

comptime {
    if (@bitSizeOf(Descriptor) != constants.layout.DESCRIPTOR_BITS) @compileError(strings.INVALID_DESCRIPTOR_SIZE);
}
