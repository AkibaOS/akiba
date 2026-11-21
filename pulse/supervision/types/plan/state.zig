//! Event Driven Service Policy State

const std = @import("std");

const Job = @import("pulse").world.types.parse.document.Job;

pub const Stage = enum { Pending, Starting, Ready, Failed, Stopped };

pub const Service = struct {
    ID: u64 = 0,
    Stage: Stage = .Pending,
    Failures: u64 = 0,
    Starts: u64 = 0,
    NeedsStop: bool = false,
    StartedAt: u64 = 0,
    StoppedAt: u64 = 0,
};

pub const Action = union(enum) { Start: usize, Stop: usize, Idle };

pub const Model = struct {
    Allocator: std.mem.Allocator,
    Jobs: []const Job,
    Order: []const usize,
    Services: []Service,
    Stopping: bool = false,
    Sequence: u64 = 0,
};
