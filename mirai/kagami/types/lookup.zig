//! Resolved Page Mapping Type

const entry = @import("mirai").kagami.types.entry;

pub const Lookup = struct {
    Entry: *const entry.Entry,
    PhysicalAddress: u64,
    PageSize: u64,
    Writable: bool,
    UserAccessible: bool,
    Executable: bool,
};
