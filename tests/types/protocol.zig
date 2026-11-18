//! Controlled Loopback Protocol Peer

const std = @import("std");

pub const Scenario = enum {
    InvalidGreeting,
    ErrorReply,
    Events,
    Reset,
    SlowGreeting,
    Disconnect,
    WrongName,
    QuitClosed,
    QuitRefused,
    LateReply,
    Headless,
};

pub const Peer = struct {
    Server: *std.net.Server,
    Scenario: Scenario,
    Failure: ?anyerror = null,
};
