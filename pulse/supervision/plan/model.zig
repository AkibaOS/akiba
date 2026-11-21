//! Keep Dependency And Restart Policy In Pulse

const std = @import("std");

const graph = @import("pulse").world.policy.graph;

const Action = @import("pulse").supervision.types.plan.state.Action;
const Document = @import("pulse").world.types.parse.document.Document;
const Model = @import("pulse").supervision.types.plan.state.Model;
const Service = @import("pulse").supervision.types.plan.state.Service;

pub fn init(allocator: std.mem.Allocator, document: *const Document) !Model {
    const services = try allocator.alloc(Service, document.Jobs.len);
    @memset(services, .{});
    return .{ .Allocator = allocator, .Jobs = document.Jobs, .Order = document.Order, .Services = services };
}

pub fn deinit(model: *Model) void {
    model.Allocator.free(model.Services);
    model.* = undefined;
}

pub fn next(model: *const Model) Action {
    var index = model.Order.len;
    while (index != 0) {
        index -= 1;
        const ordinal = model.Order[index];
        const service = model.Services[ordinal];
        if (service.ID != 0 and (service.NeedsStop or model.Stopping)) return .{ .Stop = ordinal };
    }
    if (model.Stopping) return .Idle;
    for (model.Order) |ordinal| if (eligible(model, ordinal)) return .{ .Start = ordinal };
    return .Idle;
}

pub fn started(model: *Model, index: usize, identifier: u64) !void {
    if (index >= model.Services.len or identifier == 0 or !eligible(model, index)) return error.InvalidState;
    const service = &model.Services[index];
    service.ID = identifier;
    service.Stage = .Starting;
    service.Starts +|= 1;
    service.StartedAt = advance(model);
}

pub fn ready(model: *Model, index: usize) !void {
    if (index >= model.Services.len or model.Services[index].Stage != .Starting or model.Services[index].ID == 0)
        return error.InvalidState;
    model.Services[index].Stage = .Ready;
}

pub fn failed(model: *Model, index: usize) void {
    const service = &model.Services[index];
    service.ID = 0;
    service.Stage = .Failed;
    service.Failures +|= 1;
    service.NeedsStop = false;
    invalidateDependents(model);
}

pub fn died(model: *Model, identifier: u64) bool {
    for (model.Services, 0..) |service, index| {
        if (service.ID != identifier) continue;
        failed(model, index);
        return true;
    }
    return false;
}

pub fn stopped(model: *Model, index: usize) void {
    const service = &model.Services[index];
    service.ID = 0;
    service.Stage = if (model.Stopping) .Stopped else .Pending;
    service.NeedsStop = false;
    service.StoppedAt = advance(model);
}

pub fn shutdown(model: *Model) void {
    model.Stopping = true;
}

fn eligible(model: *const Model, index: usize) bool {
    const service = model.Services[index];
    if (model.Stopping or !model.Jobs[index].Enabled or service.ID != 0 or
        (service.Stage != .Pending and service.Stage != .Failed) or service.Failures > model.Jobs[index].Restarts) return false;
    return dependenciesReady(model, index);
}

fn dependenciesReady(model: *const Model, index: usize) bool {
    for (model.Jobs[index].After) |name| {
        const dependency = graph.find(model.Jobs, name) orelse return false;
        const service = model.Services[dependency];
        if (!model.Jobs[dependency].Enabled or service.Stage != .Ready or service.NeedsStop) return false;
    }
    return true;
}

fn invalidateDependents(model: *Model) void {
    for (model.Order) |index| {
        const service = &model.Services[index];
        if (service.ID != 0 and !dependenciesReady(model, index)) service.NeedsStop = true;
    }
}

fn advance(model: *Model) u64 {
    model.Sequence +|= 1;
    return model.Sequence;
}
