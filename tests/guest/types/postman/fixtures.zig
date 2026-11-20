//! Persona Postman Regression Types

const abi = @import("mirai").invocations.types.abi;
const constants = @import("tests").guest.constants.postman.transport;
const kata = @import("mirai").kata;
const thread = @import("mirai").thread;

pub const FixtureError = error{
    DriveLimit,
    InvalidFixture,
};

pub const Operand = union(enum) {
    Immediate: u64,
    Indirect: u64,
};

pub const Operation = struct {
    Service: abi.Service,
    ServiceValue: ?u64 = null,
    First: Operand = .{ .Immediate = 0 },
    Second: u64 = 0,
    Third: u64 = 0,
    LetterType: u64 = 0,
};

pub const Program = struct {
    Bytes: [constants.PAGE_BYTES]u8,
    Length: usize,
};

pub const Actor = struct {
    Owner: *kata.types.kata.Kata,
    ID: u64,
    Code: u64,
    Data: u64,
    Stack: u64,
    Target: ?*thread.types.thread.Thread = null,
};

pub const Pair = struct {
    Peer: Actor,
    Client: Actor,
};

pub const InvocationResult = extern struct {
    Status: u64,
    Value: u64,
};

pub const Resources = struct {
    Envelopes: usize = 0,
    Mailboxes: usize = 0,
    Records: usize = 0,
};
