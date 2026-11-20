//! Real Persona Weaver For The Request Bound Diagnostic

const std = @import("std");

const afs = @import("shared").afs;
const cells = @import("tests").fixtures.afs;
const elf = @import("tests").fixtures.constants.elf.layout;
const entry = @import("fixtureasm").entry;
const fixturetext = @import("tests").fixtures.strings.elf.identities;
const inputs = @import("tests").fixtures.constants.weaver;
const invocation = @import("fixtureasm").invocation;
const labels = @import("tests").fixtures.strings.weaver;
const postmanwire = @import("tests").fixtures.constants.postman;
const provision = @import("shared").launch.constants.provision;
const storage = @import("tests").fixtures.constants.catalog;
const types = @import("tests").fixtures.types.weaver;
const weaver = @import("weaver");
const wire = @import("shared").launch.types.provision;

const LibraryCells = @import("tests").fixtures.types.catalog.LibraryCells;

const PROGRAM = @embedFile("dynamicimage");
const LIBRARY = @embedFile("dynamiclibrary");
var heap: [inputs.HEAP_BYTES]u8 = undefined;
var cache_heap: [inputs.CACHE_HEAP_BYTES]u8 = undefined;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(_: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    var cache_allocator = std.heap.FixedBufferAllocator.init(&cache_heap);
    var cache: weaver.launch.types.cache.state.Cache = .{ .Allocator = cache_allocator.allocator() };
    while (true) {
        var payload: [1]u8 = undefined;
        var header: types.Header = undefined;
        const received = invocation.call(inputs.RECEIVE, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (received.Status != provision.SUCCESS or header.ReplyTicket == 0) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
        const mode = if (header.Type == postmanwire.CALL_TYPE and header.Length == payload.len and received.Value == payload.len)
            std.enums.fromInt(types.Mode, payload[0])
        else
            null;
        const receipt = if (mode) |selected| launch(&cache, selected, header.ReplyTicket) else types.Receipt{};
        const sent = invocation.call(inputs.REPLY, header.ReplyTicket, @intFromPtr(&receipt), @sizeOf(types.Receipt), postmanwire.REPLY_TYPE);
        if (sent.Status != provision.SUCCESS) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
    }
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    invocation.exit(inputs.REJECTED_STARTUP_RESULT);
}

fn launch(cache: *weaver.launch.types.cache.state.Cache, mode: types.Mode, ticket: u64) types.Receipt {
    var request: types.Request = .{ .Mode = mode };
    const channel: weaver.launch.types.request.Channel = .{ .Ticket = ticket, .Context = &request, .Invoke = invoke };
    if (mode == .Evict) {
        weaver.launch.cache.evict(cache, channel) catch return request.Receipt;
        request.Receipt.State = .Evicted;
        return request.Receipt;
    }
    var allocator = std.heap.FixedBufferAllocator.init(&heap);
    var device: LibraryCells = undefined;
    const reader = cells.device(&device, LIBRARY, fixturetext.DYNAMIC_SOURCE, mode == .Missing) catch return request.Receipt;
    var scratch: [storage.CELL_SIZE]u8 = undefined;
    const mounted = afs.read.catalog.mount(reader, &scratch) catch return request.Receipt;
    var parameters: [inputs.PARAMETER_COUNT]u8 = @splat(inputs.PARAMETER_BYTE);
    if (mode == .Cached) parameters[0] = inputs.HOLD_PARAMETER;
    parameters[parameters.len - 1] = inputs.PARAMETER_LAST;
    const child = weaver.launch.transaction.run.run(allocator.allocator(), weaver.library.afs.source(&mounted), PROGRAM, .{
        .Biases = .{ .Executable = elf.DYNAMIC_EXECUTABLE_BIAS, .Libraries = &.{elf.DYNAMIC_LIBRARY_BIAS} },
        .Policy = .{ .MinimumAddress = elf.PAGE_BYTES, .MaximumAddress = elf.USER_END, .MaximumPages = elf.MAXIMUM_PAGES },
        .StackBase = elf.STACK_ADDRESS,
        .StackPages = 1,
        .StartupBase = inputs.STARTUP_ADDRESS,
        .Identity = labels.IDENTITY,
        .Parameters = &parameters,
        .Cache = if (mode == .Cached or mode == .Mismatch or mode == .ProtectionMismatch) cache else null,
    }, channel) catch |failure| {
        request.Receipt.State = switch (failure) {
            error.LibraryNotFound => .MissingLibrary,
            error.ProvisionRefused => .Refused,
            else => .Failed,
        };
        return request.Receipt;
    };
    request.Receipt.Child = child;
    request.Receipt.State = .Started;
    return request.Receipt;
}

fn invoke(context: *anyopaque, ticket: u64, operation: wire.Operation, argument: u64, protection: wire.Protection) wire.Result {
    const request: *types.Request = @ptrCast(@alignCast(context));
    if (operation == .Begin) request.Receipt.Begins += 1;
    const result = refused: {
        if (operation == .AttachVerified) {
            if (request.Mode == .Mismatch) {
                const supplied: *const wire.AttachVerified = @ptrFromInt(argument);
                const source: *const [elf.PAGE_BYTES]u8 = @ptrFromInt(supplied.Source);
                var different = source.*;
                different[0] ^= 1;
                var invalid = supplied.*;
                invalid.Source = @intFromPtr(&different);
                break :refused invocation.call(provision.SERVICE, ticket, @intFromEnum(operation), @intFromPtr(&invalid), @intFromEnum(protection));
            }
            if (request.Mode == .ProtectionMismatch) {
                const different: wire.Protection = if (protection == .ReadOnly) .ReadExecute else .ReadOnly;
                break :refused invocation.call(provision.SERVICE, ticket, @intFromEnum(operation), argument, @intFromEnum(different));
            }
        }
        if (operation == .Load and request.Mode == .RefuseLoad and request.Receipt.Allocations == 2) {
            const supplied: *const wire.Load = @ptrFromInt(argument);
            var invalid = supplied.*;
            invalid.Source = 0;
            break :refused invocation.call(provision.SERVICE, ticket, @intFromEnum(operation), @intFromPtr(&invalid), @intFromEnum(protection));
        }
        break :refused invocation.call(provision.SERVICE, ticket, @intFromEnum(operation), argument, @intFromEnum(protection));
    };
    if (result.Status == provision.SUCCESS) {
        if (operation == .Allocate) request.Receipt.Allocations += 1;
        if (operation == .Abort) request.Receipt.Aborts += 1;
        if (operation == .Retain) request.Receipt.Retained += 1;
        if (operation == .AttachVerified) request.Receipt.Attached += 1;
    } else {
        request.Receipt.RejectedStatus = result.Status;
    }
    return .{ .Status = result.Status, .Value = result.Value };
}
