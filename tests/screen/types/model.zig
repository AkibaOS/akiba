//! Diagnostic Test Progress And Visible Rows

pub const Kind = enum { Info, Running, Pass, Fail };
pub const Outcome = enum { Pass, Fail };

pub const Row = struct {
    Kind: Kind,
    Text: []const u8,
    Repeats: usize = 1,
    Verified: ?usize = null,
};

pub const Model = struct {
    Rows: []Row,
    Total: usize,
    Oldest: usize = 0,
    Count: usize = 0,
    Completed: usize = 0,
    Failed: usize = 0,
    Active: ?[]const u8 = null,
    ActiveVerified: ?usize = null,
    TailIsPassEvidence: bool = false,
    Done: bool = false,
    MenuReady: bool = false,
    CancelReady: bool = false,
};
