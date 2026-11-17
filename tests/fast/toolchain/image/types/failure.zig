//! Active Disk Image I O Failure Fixture State

pub const Kind = enum {
    Read,
    Write,
    Sync,
    Rename,
    ShortRead,
    SourceChange,
};

pub const Context = struct {
    Kind: Kind,
    ReadCalls: usize = 0,
    WriteCalls: usize = 0,
    SourcePath: []const u8 = &.{},
    Changed: bool = false,
};
