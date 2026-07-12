//! TSS GDT Entry

const types = @import("../../types/gdt/gdt.zig");
const constants = @import("../../constants/gdt/gdt.zig");

const TssDescriptor = types.TssDescriptor;
const access = constants.access;

pub fn create_tss_descriptor(tss_address: u64, tss_size: u20) TssDescriptor {
    return TssDescriptor.init(
        tss_address,
        tss_size,
        access.tss_access,
    );
}

pub fn mark_tss_busy(descriptor: *TssDescriptor) void {
    descriptor.access = access.tss_access_busy;
}

pub fn mark_tss_available(descriptor: *TssDescriptor) void {
    descriptor.access = access.tss_access;
}
