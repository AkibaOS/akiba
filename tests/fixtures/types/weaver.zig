//! Diagnostic Weaver Call Payload And Observations

pub const Mode = enum(u8) { Missing, RefuseLoad, Launch, Cached, Mismatch, ProtectionMismatch, Evict };
pub const Outcome = enum(u64) { Started, MissingLibrary, Refused, Failed, Evicted };

pub const Header = extern struct {
    Sender: u64,
    Type: u64,
    Length: u64,
    ReplyTicket: u64,
};

pub const Receipt = extern struct {
    Child: u64 = 0,
    State: Outcome = .Failed,
    Begins: u64 = 0,
    Allocations: u64 = 0,
    Aborts: u64 = 0,
    RejectedStatus: u64 = 0,
    Retained: u64 = 0,
    Attached: u64 = 0,
};

pub const Request = struct {
    Mode: Mode,
    Receipt: Receipt = .{},
};
