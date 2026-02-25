//! Kernel GDT Entries

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");

const Entry = types.Entry;
const access = constants.access;
const flags = constants.flags;

pub fn create_kernel_code() Entry {
    return Entry.init(
        0,
        0xFFFFF,
        access.kernel_code_access,
        flags.kernel_code_flags,
    );
}

pub fn create_kernel_data() Entry {
    return Entry.init(
        0,
        0xFFFFF,
        access.kernel_data_access,
        flags.kernel_data_flags,
    );
}
