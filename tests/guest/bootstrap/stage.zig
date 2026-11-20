//! Diagnostic Adapter For Owned Linked Persona Pages

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const driver = @import("tests").guest.sensei.support;
const elf = @import("shared").elf;
const fixturetext = @import("tests").fixtures.strings.elf.identities;
const inputs = @import("tests").fixtures.constants.elf.layout;
const kata = @import("mirai").kata;
const sizes = @import("common").constants.memory.sizes;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;
const weaver = @import("weaver");

const Kata = kata.types.kata.Kata;
const Layout = elf.types.dynamic.Layout;
const Plan = weaver.link.types.link.Plan;
const Prepared = bootstrap.types.image.preparation.Prepared;
const Protection = user.types.protection.Protection;
const ReadError = weaver.library.errors.library.ReadError;
const Source = @import("tests").guest.types.elf.Source;

pub fn prepare(launcher: *const Kata, plan: *const Plan, first: ?*const Kata) !Prepared {
    const owner = try kata.create.createFor(launcher);
    errdefer driver.dispose(owner.ID) catch |failure| verify.failure(failure);
    var buffer: [sizes.PAGE_SIZE]u8 = undefined;
    var stream: weaver.stage.types.page.stream.Stream = .{ .Link = plan };
    while (weaver.stage.page.next.next(&stream, &buffer)) |page| {
        if (page.ImmutableLibrary) {
            if (first) |source| {
                try user.memory.share.map(source, page.Address, owner, page.Address);
                continue;
            }
        }
        try user.memory.allocate.allocate(owner, page.Address);
        try user.memory.load.load(owner, page.Address, &buffer);
        const protection: Protection = switch (page.Access) {
            .ReadOnly => .ReadOnly,
            .ReadWrite => .ReadWrite,
            .ReadExecute => .ReadExecute,
        };
        try user.memory.finalize.finalize(owner, page.Address, protection);
    }
    const options: bootstrap.types.image.preparation.Options = .{ .StackBase = inputs.STACK_ADDRESS, .StackPages = 1 };
    try bootstrap.image.memory.allocateStack(owner, options);
    try bootstrap.image.memory.finalizeStack(owner, options);
    const target = try thread.user.create(owner, plan.Placement.Executable.Image.Entry, options.StackBase, sizes.PAGE_SIZE, 0);
    const generation = thread.state.generation(target) orelse return error.InvalidFixture;
    return .{ .ID = owner.ID, .Owner = owner, .Thread = target, .ThreadGeneration = generation };
}

pub fn access(source: *const Source) weaver.library.types.source.Source {
    return .{ .Context = source, .ReadFromOrigin = read };
}

fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, name: []const u8) ReadError!?[]u8 {
    const source: *const Source = @ptrCast(@alignCast(context));
    const expected = weaver.library.strings.location.SYSTEM_LIBRARIES;
    if (!std.mem.eql(u8, name, fixturetext.DYNAMIC_SOURCE) or parent.len != expected.len) return null;
    for (parent, expected) |actual, component| if (!std.mem.eql(u8, actual, component)) return null;
    return try allocator.dupe(u8, source.Library orelse return null);
}

pub fn codeAddress(layout: *const Layout) !u64 {
    var address: ?u64 = null;
    for (layout.Image.Segments) |segment| {
        if (!segment.isExecutable()) continue;
        if (address != null) return error.InvalidFixture;
        address = segment.VirtualAddress & ~sizes.PAGE_MASK;
    }
    return address orelse error.InvalidFixture;
}

pub fn counterAddress(layout: *const Layout) !u64 {
    for (layout.Metadata.Symbols) |symbol| {
        if (std.mem.eql(u8, try layout.Metadata.string(symbol.NameOffset), fixturetext.DYNAMIC_COUNTER)) {
            return std.math.add(u64, layout.Bias, symbol.Value) catch return error.InvalidFixture;
        }
    }
    return error.InvalidFixture;
}

pub fn readCounter(owner: *const Kata, address: u64) !u64 {
    var bytes: [@sizeOf(u64)]u8 = undefined;
    try user.copy.transfer.read(owner, &bytes, address);
    return std.mem.readInt(u64, &bytes, .little);
}
