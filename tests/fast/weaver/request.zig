//! Linked Provision Transaction And Rollback Checks

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
const fixture = @import("tests").fixtures.bytes.elf;
const inputs = @import("tests").fixtures.constants.elf;
const shared = @import("shared");
const weaver = @import("weaver");

const ABI = shared.launch.types.provision;
const ALLOCATOR = std.testing.allocator;
const STARTUP: u64 = 0x71000000;
const TICKET: u64 = 7;
const CHILD: u64 = 42;
const PARAMETERS = [_]u8{0xa5} ** (inputs.PAGE_BYTES + 1);
const TABLE = inputs.PAGE_BYTES + inputs.DYNAMIC_TABLE;
const RELOCATION = inputs.PAGE_BYTES + inputs.DYNAMIC_RELA;

const Sink = struct {
    Begin: usize = 0,
    Allocated: usize = 0,
    Loaded: usize = 0,
    Sealed: usize = 0,
    Aborted: usize = 0,
    Start: ?ABI.Start = null,
    Bytes: [2 * inputs.PAGE_BYTES]u8 = @splat(0),
    RefuseLoad: bool = false,
    RefuseAbort: bool = false,

    fn invoke(context: *anyopaque, ticket: u64, operation: ABI.Operation, argument: u64, _: ABI.Protection) ABI.Result {
        const sink: *Sink = @ptrCast(@alignCast(context));
        if (ticket != TICKET) return .{ .Status = 11 };
        switch (operation) {
            .Begin => sink.Begin += 1,
            .Abort => {
                sink.Aborted += 1;
                if (sink.RefuseAbort) return .{ .Status = 15 };
            },
            .Allocate => sink.Allocated += 1,
            .Load => {
                sink.Loaded += 1;
                if (sink.RefuseLoad and sink.Loaded == 2) return .{ .Status = 4 };
                const descriptor: *const ABI.Load = @ptrFromInt(argument);
                if (descriptor.Destination >= STARTUP) {
                    const offset: usize = @intCast(descriptor.Destination - STARTUP);
                    const count: usize = @intCast(descriptor.Length);
                    const source: [*]const u8 = @ptrFromInt(descriptor.Source);
                    @memcpy(sink.Bytes[offset..][0..count], source[0..count]);
                }
            },
            .Seal => sink.Sealed += 1,
            .Start => {
                const descriptor: *const ABI.Start = @ptrFromInt(argument);
                sink.Start = descriptor.*;
                return .{ .Value = CHILD };
            },
        }
        return .{};
    }
};

pub fn commits() !void {
    var sink: Sink = .{};
    try std.testing.expectEqual(CHILD, try launch(&sink, true, STARTUP));
    try std.testing.expectEqual(@as(usize, 1), sink.Begin);
    try std.testing.expectEqual(@as(usize, 7), sink.Allocated);
    try std.testing.expectEqual(@as(usize, 8), sink.Loaded);
    try std.testing.expectEqual(sink.Allocated, sink.Sealed);
    try std.testing.expectEqual(@as(usize, 0), sink.Aborted);
    const start = sink.Start orelse return error.InvalidFixture;
    try std.testing.expectEqual(@as(u64, 0x206001), start.Entry);
    try std.testing.expectEqual(@as(u64, inputs.STACK_ADDRESS), start.StackBase);
    try std.testing.expectEqual(@as(u64, inputs.PAGE_BYTES), start.StackLength);
    try std.testing.expectEqual(STARTUP, start.Startup);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1, 16, 0, 0, 0, 0, 0, 0 }, sink.Bytes[0..24]);
    try std.testing.expectEqualStrings("app", sink.Bytes[24..27]);
    try std.testing.expectEqualSlices(u8, &PARAMETERS, sink.Bytes[27..][0..PARAMETERS.len]);
}

pub fn rejectsBeforeBegin() !void {
    var sink: Sink = .{};
    try std.testing.expectError(error.LibraryNotFound, launch(&sink, false, STARTUP));
    try std.testing.expectError(error.AddressOverlap, launch(&sink, true, 0x205000));
    try std.testing.expectEqual(@as(usize, 0), sink.Begin);
    try std.testing.expectEqual(@as(usize, 0), sink.Allocated);
    try std.testing.expectEqual(@as(usize, 0), sink.Aborted);
}

pub fn aborts() !void {
    var sink: Sink = .{ .RefuseLoad = true };
    try std.testing.expectError(error.ProvisionRefused, launch(&sink, true, STARTUP));
    try std.testing.expectEqual(@as(usize, 2), sink.Allocated);
    try std.testing.expectEqual(@as(usize, 1), sink.Aborted);
    try std.testing.expect(sink.Start == null);
    sink = .{ .RefuseLoad = true, .RefuseAbort = true };
    try std.testing.expectError(error.RollbackRefused, launch(&sink, true, STARTUP));
    try std.testing.expectEqual(@as(usize, 1), sink.Aborted);
    try std.testing.expect(sink.Start == null);
}

fn launch(sink: *Sink, available: bool, startup_address: u64) !u64 {
    var executable = dynamic.loadImage();
    var library = dynamic.loadImage();
    prepare(&executable);
    prepare(&library);
    fixture.write64(&library, TABLE, 21);
    fixture.write64(&library, TABLE + 8, 0);
    const source: ?[]const u8 = if (available) &library else null;
    return weaver.launch.run.run(ALLOCATOR, .{ .Context = &source, .ReadFromOrigin = read }, &executable, .{
        .Biases = .{ .Executable = 0x200000, .Libraries = &.{0x400000} },
        .Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES },
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 1,
        .StartupBase = startup_address,
        .Identity = "app",
        .Parameters = &PARAMETERS,
    }, .{ .Ticket = TICKET, .Context = sink, .Invoke = Sink.invoke });
}

fn prepare(bytes: []u8) void {
    fixture.write64(bytes, RELOCATION, 0x53f8);
    fixture.write64(bytes, RELOCATION + 16, 0x5400);
    fixture.write64(bytes, TABLE + 11 * inputs.DYNAMIC_WORD_BYTES + 8, 0);
}

fn read(context: *const anyopaque, allocator: std.mem.Allocator, _: []const []const u8, _: []const u8) weaver.library.errors.library.ReadError!?[]u8 {
    const source: *const ?[]const u8 = @ptrCast(@alignCast(context));
    return try allocator.dupe(u8, source.* orelse return null);
}
