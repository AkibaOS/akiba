//! AFS Manifest Catalog Entries

pub const EntryKind = enum {
    Stack,
    Unit,
};

pub const Entry = struct {
    ParentNodeId: u32,
    NodeId: u32,
    Identity: []const u8,
    Path: []const u8 = &.{},
    Kind: EntryKind,
    LogicalSize: u64 = 0,
    Timestamp: u64 = 0,
};
