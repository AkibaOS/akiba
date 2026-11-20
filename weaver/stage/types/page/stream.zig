//! Linked Page Stream And Final Protection

const elf = @import("shared").elf;

const Layout = elf.types.dynamic.Layout;
const Plan = @import("weaver").link.types.link.Plan;
const Write = elf.types.relocation.Write;

pub const Access = enum { ReadOnly, ReadWrite, ReadExecute };

pub const Page = struct {
    Address: u64,
    Access: Access,
    LibraryIndex: ?usize,
    ImmutableLibrary: bool,
};

pub const View = struct {
    Bytes: []const u8,
    Layout: *const Layout,
    Writes: []const Write,
};

pub const Stream = struct {
    Link: *const Plan,
    ImageIndex: usize = 0,
    RangeIndex: usize = 0,
    Address: u64 = 0,
    SegmentIndex: usize = 0,
    WriteIndex: usize = 0,
};
