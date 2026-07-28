//! GDT Entry Creation

const constants = @import("mirai").boot.constants;
const types = @import("mirai").boot.types;

const access = constants.gdt.access;
const flags = constants.gdt.flags;

const Entry = types.gdt.entry.Entry;
const TSSDescriptor = types.gdt.tss.TSSDescriptor;

pub fn createKernelCode() Entry {
    return Entry.init(
        0,
        flags.SEGMENT_LIMIT,
        access.KERNEL_CODE_ACCESS,
        flags.KERNEL_CODE_FLAGS,
    );
}

pub fn createKernelData() Entry {
    return Entry.init(
        0,
        flags.SEGMENT_LIMIT,
        access.KERNEL_DATA_ACCESS,
        flags.KERNEL_DATA_FLAGS,
    );
}

pub fn createUserCode() Entry {
    return Entry.init(
        0,
        flags.SEGMENT_LIMIT,
        access.USER_CODE_ACCESS,
        flags.USER_CODE_FLAGS,
    );
}

pub fn createUserData() Entry {
    return Entry.init(
        0,
        flags.SEGMENT_LIMIT,
        access.USER_DATA_ACCESS,
        flags.USER_DATA_FLAGS,
    );
}

pub fn createTSSDescriptor(tss_address: u64, tss_size: u20) TSSDescriptor {
    return TSSDescriptor.init(
        tss_address,
        tss_size,
        access.TSS_ACCESS,
    );
}

pub fn markTSSBusy(descriptor: *TSSDescriptor) void {
    descriptor.Access = access.TSS_ACCESS_BUSY;
}

pub fn markTSSAvailable(descriptor: *TSSDescriptor) void {
    descriptor.Access = access.TSS_ACCESS;
}
