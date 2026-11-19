//! Early Memory Map Conversion Beyond Fixed Descriptor Storage

const std = @import("std");

const boot = @import("shared").boot;
const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const conversion = @import("mirai").boot.regions.convert;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.regions;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.regions;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Descriptor = boot.types.memory.UefiMemoryDescriptor;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const before = pmm.state.getStatistics();
    try check(inputs.COUNT, inputs.STRIDE, false, labels.GROWTH);
    try check(2, inputs.WIDE_STRIDE, false, labels.STRIDE);
    try check(inputs.COUNT, inputs.WIDE_STRIDE, true, labels.GROWTH);
    try malformed();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
}

fn malformed() !void {
    const physical = try pmm.allocate.single.allocatePageZeroed();
    defer pmm.free.single.freePage(physical);
    const buffer: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    const first: *Descriptor = @ptrCast(@alignCast(buffer));
    const second: *Descriptor = @ptrCast(@alignCast(buffer + inputs.STRIDE));
    first.* = .{ .MemoryType = .Conventional, .PhysicalStart = 2 * sizes.PAGE_SIZE, .VirtualStart = 0, .NumberOfPages = 1, .Attribute = 0 };
    second.* = .{ .MemoryType = .LoaderData, .PhysicalStart = 4 * sizes.PAGE_SIZE, .VirtualStart = 0, .NumberOfPages = 1, .Attribute = 0 };
    const info: boot.types.memory.MemoryMapInfo = .{
        .Entries = physical,
        .EntryCount = 2,
        .EntrySize = inputs.STRIDE,
        .DescriptorVersion = boot.constants.memory.DESCRIPTOR_VERSION,
        .Reserved = 0,
    };
    const limit = kagami.state.getPolicy().PhysmapSize;
    var bad = info;
    bad.EntrySize = 0;
    var correct = conversion.consume(bad, limit) == null;
    bad = info;
    bad.EntryCount = 0;
    correct = correct and conversion.consume(bad, limit) == null;
    bad = info;
    bad.DescriptorVersion += 1;
    correct = correct and conversion.consume(bad, limit) == null;
    bad = info;
    bad.Entries = limit - @alignOf(Descriptor);
    correct = correct and conversion.consume(bad, limit) == null;
    second.NumberOfPages = 0;
    var original: [2 * inputs.STRIDE]u8 = undefined;
    @memcpy(&original, buffer[0..original.len]);
    correct = correct and conversion.consume(info, limit) == null;
    verify.require(std.mem.eql(u8, &original, buffer[0..original.len]), labels.PRESERVE);
    second.NumberOfPages = std.math.maxInt(u64);
    correct = correct and conversion.consume(info, limit) == null;
    second.NumberOfPages = 1;
    second.PhysicalStart += 1;
    correct = correct and conversion.consume(info, limit) == null;
    second.PhysicalStart = first.PhysicalStart;
    correct = correct and conversion.consume(info, limit) == null;
    verify.require(correct, labels.REJECT);
}

fn check(count: u32, stride: u32, descending: bool, comptime label: []const u8) !void {
    const bytes = @as(u64, count) * stride;
    const pages = bytes / sizes.PAGE_SIZE + @intFromBool(bytes % sizes.PAGE_SIZE != 0);
    const physical = try pmm.allocate.contiguous.allocateContiguousZeroed(pages);
    defer pmm.free.range.freeRange(physical, pages);
    const buffer: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    for (0..count) |index| {
        const descriptor: *Descriptor = @ptrCast(@alignCast(buffer + index * stride));
        const ordinal = if (descending) count - index - 1 else index;
        descriptor.* = .{
            .MemoryType = if (ordinal % 2 == 0) .Conventional else .LoaderData,
            .PhysicalStart = (ordinal + 1) * 2 * sizes.PAGE_SIZE,
            .VirtualStart = 0,
            .NumberOfPages = 1,
            .Attribute = 0,
        };
    }
    const info: boot.types.memory.MemoryMapInfo = .{
        .Entries = physical,
        .EntryCount = count,
        .EntrySize = stride,
        .DescriptorVersion = boot.constants.memory.DESCRIPTOR_VERSION,
        .Reserved = 0,
    };
    const limit = kagami.state.getPolicy().PhysmapSize;
    const raw = conversion.inspect(info, limit).?;
    const backing = conversion.ownsLoaderBacking(raw, .{ .Start = 4, .End = 5 }) and
        !conversion.ownsLoaderBacking(raw, .{ .Start = 4, .End = 6 }) and
        !conversion.ownsLoaderBacking(raw, .{ .Start = 2, .End = 3 });
    budget.arm(0);
    const converted = conversion.consume(info, limit);
    budget.clear();
    verify.require(backing and converted != null and converted.?.len == count, label);
    var correct = true;
    for (converted.?, 0..) |region, index| correct = correct and region.BaseAddress == (index + 1) * 2 * sizes.PAGE_SIZE and
        region.Length == sizes.PAGE_SIZE and region.RegionType == (if (index % 2 == 0) pmm.types.region.RegionType.Available else .LoaderData);
    verify.require(correct, label);
}
