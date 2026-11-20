//! Private Request Bound Provision Invocation Fields

const std = @import("std");

const wire = @import("shared").launch.constants.provision;

pub const Operation = enum(u64) {
    Begin = 0,
    Abort = 1,
    Allocate = 2,
    Load = 3,
    Seal = 4,
    Start = 5,
    Retain = 6,
    Attach = 7,
    Forget = 8,
    AttachVerified = 9,
};

pub const Protection = enum(u64) {
    ReadOnly = 0,
    ReadWrite = 1,
    ReadExecute = 2,
};

pub const Load = extern struct {
    Destination: u64,
    Source: u64,
    Length: u64,
};

pub const Start = extern struct {
    Entry: u64,
    StackBase: u64,
    StackLength: u64,
    Startup: u64,
};

pub const Attach = extern struct {
    Handle: u64,
    Address: u64,
};

pub const AttachVerified = extern struct {
    Handle: u64,
    Address: u64,
    Source: u64,
};

pub const Result = struct {
    Status: u64 = wire.SUCCESS,
    Value: u64 = 0,
};

comptime {
    std.debug.assert(@sizeOf(Load) == 3 * @sizeOf(u64));
    std.debug.assert(@sizeOf(Start) == 4 * @sizeOf(u64));
    std.debug.assert(@sizeOf(Attach) == 2 * @sizeOf(u64));
    std.debug.assert(@sizeOf(AttachVerified) == 3 * @sizeOf(u64));
}
