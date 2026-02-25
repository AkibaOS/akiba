//! CPU Phase

const gdt = @import("../../gdt/gdt.zig");
const tss = @import("../../tss/tss.zig");
const tss_constants = @import("../../tss/constants/constants.zig");
const serial = @import("../../../drivers/serial/serial.zig");

pub fn execute() bool {
    serial.printf("Setting up Task State Segment for CPU exceptions\n", .{});
    tss.initialize_boot();

    serial.printf("Setting up Global Descriptor Table with kernel and user segments\n", .{});
    const tss_address = tss.get_boot_tss_address();
    gdt.initialize(tss_address, tss_constants.tss_size);

    return true;
}
