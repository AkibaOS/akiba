//! User GDT Entries

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");

const Entry = types.Entry;
const access = constants.access;
const flags = constants.flags;

pub fn create_user_code() Entry {
    return Entry.init(
        0,
        0xFFFFF,
        access.user_code_access,
        flags.user_code_flags,
    );
}

pub fn create_user_data() Entry {
    return Entry.init(
        0,
        0xFFFFF,
        access.user_data_access,
        flags.user_data_flags,
    );
}
