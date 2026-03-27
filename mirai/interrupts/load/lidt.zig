//! LIDT Operations

const types = @import("../types/types.zig");
const table = @import("../table/table.zig");
const asm_int = @import("../../asm/interrupts/interrupts.zig");

pub fn lidt(desc: *const types.Descriptor) void {
    asm_int.lidt(desc);
}

pub fn load() void {
    const desc = types.Descriptor.from_table(&table.entries.entries);
    lidt(&desc);
}

pub fn sidt() types.Descriptor {
    var desc: types.Descriptor = undefined;
    asm_int.sidt(&desc);
    return desc;
}
