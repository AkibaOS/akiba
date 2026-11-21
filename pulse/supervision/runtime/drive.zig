//! Apply Pulse Policy Using Real Weaver And Service Endpoints

const binary = @import("pulse").supervision.client.binary;
const defaults = @import("pulse").world.constants.defaults;
const policy = @import("pulse").supervision.plan.model;
const service = @import("pulse").supervision.client.service;

const Context = @import("pulse").supervision.types.runtime.context.Context;

pub fn run(context: *Context) !void {
    while (true) {
        switch (policy.next(context.Plan)) {
            .Start => |index| {
                const job = context.Plan.Jobs[index];
                const identifier = binary.start(context.Allocator, context.WeaverID, context.PulseID, job, context.Catalog) catch |failure| {
                    if (failure == error.ShutdownFailed or failure == error.CollectionFailed) return failure;
                    policy.failed(context.Plan, index);
                    continue;
                };
                policy.started(context.Plan, index, identifier) catch |failure| {
                    try service.stop(identifier, job.Timeout);
                    return failure;
                };
                if (!service.ready(identifier, job.Timeout)) {
                    try service.stop(identifier, job.Timeout);
                    policy.failed(context.Plan, index);
                    continue;
                }
                try policy.ready(context.Plan, index);
            },
            .Stop => |index| {
                try service.stop(context.Plan.Services[index].ID, context.Plan.Jobs[index].Timeout);
                policy.stopped(context.Plan, index);
            },
            .Idle => {
                if (context.Phase == .Stopping) try stopCore(context);
                return;
            },
        }
    }
}

pub fn outcome(context: *Context, identifier: u64) !void {
    try service.collect(identifier);
    if (policy.died(context.Plan, identifier)) return;
    if (identifier == context.WeaverID or identifier == context.DiskID or identifier == context.AfsID) {
        if (identifier == context.WeaverID) context.WeaverID = 0;
        if (identifier == context.AfsID) context.AfsID = 0;
        if (identifier == context.DiskID) context.DiskID = 0;
        context.Phase = .Degraded;
        policy.shutdown(context.Plan);
    }
}

pub fn startupReady(context: *const Context) bool {
    for (context.Plan.Jobs, context.Plan.Services) |job, running| {
        if (job.Enabled and job.Required and running.Stage != .Ready) return false;
    }
    return context.Phase != .Degraded;
}

pub fn degraded(context: *const Context) bool {
    for (context.Plan.Jobs, context.Plan.Services) |job, running| {
        if (job.Enabled and running.Stage != .Ready) return true;
    }
    return false;
}

fn stopCore(context: *Context) !void {
    if (context.WeaverID != 0) {
        try service.stop(context.WeaverID, defaults.TIMEOUT_TICKS);
        context.WeaverID = 0;
    }
    if (context.AfsID != 0) {
        try service.stop(context.AfsID, defaults.TIMEOUT_TICKS);
        context.AfsID = 0;
    }
    if (context.DiskID != 0) {
        try service.stop(context.DiskID, defaults.TIMEOUT_TICKS);
        context.DiskID = 0;
    }
    context.Phase = .Stopped;
}
