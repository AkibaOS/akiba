//! Controlled Loopback Protocol Peer

const std = @import("std");

pub const Scenario = enum {
    InvalidGreeting,
    ErrorReply,
    Events,
    SlowGreeting,
    Disconnect,
    WrongName,
};

pub const Peer = struct {
    Server: *std.net.Server,
    Scenario: Scenario,
    Failure: ?anyerror = null,
};
