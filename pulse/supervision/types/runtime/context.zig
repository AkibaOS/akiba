//! System Supervisor Runtime Ownership

const std = @import("std");

const Model = @import("pulse").supervision.types.plan.state.Model;
const Phase = @import("shared").pulse.types.supervision.report.Phase;

pub const Context = struct {
    Allocator: std.mem.Allocator,
    Plan: *Model,
    PulseID: u64,
    WeaverID: u64,
    DiskID: u64,
    AfsID: u64,
    Phase: Phase = .Starting,
};
