//! Prepare And Commit One Request Bound Linked Launch

const std = @import("std");

const launch = @import("weaver").launch;
const weaver = @import("weaver");

const Channel = launch.types.request.Channel;
const Options = launch.types.request.Options;
const RequestError = launch.errors.request.RequestError;
const Source = weaver.library.types.source.Source;

pub fn run(allocator: std.mem.Allocator, source: Source, executable: []const u8, options: Options, channel: Channel) RequestError!u64 {
    if (channel.Ticket == 0) return error.InvalidTicket;
    const spans = try launch.reserve.reserve(options);
    var graph = try weaver.library.load.collect.collect(allocator, source, executable);
    defer graph.deinit();
    var placement = try weaver.image.place.place(allocator, &graph, options.Biases, options.Policy, &.{ spans.GuardedStack, spans.Startup });
    defer placement.deinit();
    var linked = try weaver.link.plan.plan(allocator, &placement);
    defer linked.deinit();
    const boundary = if (options.Cache) |cache| try launch.cache.begin(cache) else 0;
    var committed = false;
    defer if (options.Cache) |cache| launch.cache.finish(cache, boundary, committed);
    _ = try launch.transaction.stage.invoke(channel, .Begin, 0, .ReadOnly);
    const child = launch.transaction.stage.stage(channel, &linked, options, spans, boundary) catch |failure| {
        _ = launch.transaction.stage.invoke(channel, .Abort, 0, .ReadOnly) catch return error.RollbackRefused;
        return failure;
    };
    committed = true;
    if (child == 0) return error.InvalidChild;
    return child;
}
