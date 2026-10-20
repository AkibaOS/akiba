//! Hikari Page Mapping Types

const entry = @import("hikari").paging.types.entry;

pub const AliasMode = enum {
    KernelReadOnly,
    KernelReadWrite,
    Framebuffer,
};

pub const Leaf = struct {
    Entry: *entry.PageTableEntry,
    Size: u64,
};
