//! Hikari Page Mapping Types

const entry = @import("hikari").paging.types.entry;

pub const Leaf = struct {
    Entry: *entry.PageTableEntry,
    Size: u64,
};
