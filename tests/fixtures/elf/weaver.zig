//! Real Persona Weaver For The Request Bound Diagnostic

const std = @import("std");

const elf = @import("tests").fixtures.constants.elf;
const entry = @import("fixtureasm").entry;
const fixturetext = @import("tests").fixtures.strings.elf;
const inputs = @import("tests").fixtures.constants.weaver;
const invocation = @import("fixtureasm").invocation;
const labels = @import("tests").fixtures.strings.weaver;
const postmanwire = @import("tests").fixtures.constants.postman;
const provision = @import("shared").launch.constants.provision;
const types = @import("tests").fixtures.types.weaver;
const weaver = @import("weaver");
const wire = @import("shared").launch.types.provision;

const PROGRAM = @embedFile("dynamicimage");
const LIBRARY = @embedFile("dynamiclibrary");
var heap: [inputs.HEAP_BYTES]u8 = undefined;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(_: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    while (true) {
        var payload: [1]u8 = undefined;
        var header: types.Header = undefined;
        const received = invocation.call(inputs.RECEIVE, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (received.Status != provision.SUCCESS or header.ReplyTicket == 0) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
        const mode = if (header.Type == postmanwire.CALL_TYPE and header.Length == payload.len and received.Value == payload.len)
            std.enums.fromInt(types.Mode, payload[0])
        else
            null;
        const receipt = if (mode) |selected| launch(selected, header.ReplyTicket) else types.Receipt{};
        const sent = invocation.call(inputs.REPLY, header.ReplyTicket, @intFromPtr(&receipt), @sizeOf(types.Receipt), postmanwire.REPLY_TYPE);
        if (sent.Status != provision.SUCCESS) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
    }
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    invocation.exit(inputs.REJECTED_STARTUP_RESULT);
}

fn launch(mode: types.Mode, ticket: u64) types.Receipt {
    var allocator = std.heap.FixedBufferAllocator.init(&heap);
    var request: types.Request = .{ .Mode = mode };
    var parameters: [inputs.PARAMETER_COUNT]u8 = @splat(inputs.PARAMETER_BYTE);
    parameters[parameters.len - 1] = inputs.PARAMETER_LAST;
    const child = weaver.launch.transaction.run.run(allocator.allocator(), .{ .Context = &request, .ReadFromOrigin = read }, PROGRAM, .{
        .Biases = .{ .Executable = elf.DYNAMIC_EXECUTABLE_BIAS, .Libraries = &.{elf.DYNAMIC_LIBRARY_BIAS} },
        .Policy = .{ .MinimumAddress = elf.PAGE_BYTES, .MaximumAddress = elf.USER_END, .MaximumPages = elf.MAXIMUM_PAGES },
        .StackBase = elf.STACK_ADDRESS,
        .StackPages = 1,
        .StartupBase = inputs.STARTUP_ADDRESS,
        .Identity = labels.IDENTITY,
        .Parameters = &parameters,
    }, .{ .Ticket = ticket, .Context = &request, .Invoke = invoke }) catch |failure| {
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

fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, name: []const u8) weaver.library.errors.library.ReadError!?[]u8 {
    const request: *const types.Request = @ptrCast(@alignCast(context));
    const expected = weaver.library.strings.location.SYSTEM_LIBRARIES;
    if (request.Mode == .Missing or parent.len != expected.len or !std.mem.eql(u8, name, fixturetext.DYNAMIC_SOURCE)) return null;
    for (parent, expected) |actual, component| if (!std.mem.eql(u8, actual, component)) return null;
    return try allocator.dupe(u8, LIBRARY);
}

fn invoke(context: *anyopaque, ticket: u64, operation: wire.Operation, argument: u64, protection: wire.Protection) wire.Result {
    const request: *types.Request = @ptrCast(@alignCast(context));
    if (operation == .Begin) request.Receipt.Begins += 1;
    const result = refused: {
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
    } else {
        request.Receipt.RejectedStatus = result.Status;
    }
    return .{ .Status = result.Status, .Value = result.Value };
}
