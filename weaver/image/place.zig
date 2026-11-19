//! Check The Complete Native Graph Address Space

const std = @import("std");

const elf = @import("shared").elf;
const image = @import("weaver").image;
const sizes = @import("common").constants.memory.sizes;

const Biases = image.types.layout.Biases;
const Graph = @import("weaver").library.types.graph.Graph;
const Interval = image.types.layout.Interval;
const Layout = elf.types.dynamic.Layout;
const LayoutError = image.errors.layout.LayoutError;
const Placement = image.types.layout.Placement;
const Policy = elf.types.image.Policy;

pub fn place(allocator: std.mem.Allocator, graph: *const Graph, biases: Biases, policy: Policy, reserved: []const Interval) LayoutError!Placement {
    if (biases.Libraries.len != graph.Libraries.len) return error.InvalidPlacement;
    try elf.validate.load.validatePolicy(policy);
    try checkReservations(reserved, policy);
    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    try intervals.appendSlice(allocator, reserved);

    var executable = try elf.validate.dynamic.parse(allocator, graph.Executable, biases.Executable, .Executable, policy);
    errdefer executable.Image.deinit();
    try addImage(allocator, &intervals, &executable);
    var remaining = policy.MaximumPages - executable.Image.Pages;

    const libraries = try allocator.alloc(Layout, graph.Libraries.len);
    errdefer allocator.free(libraries);
    var placed: usize = 0;
    errdefer for (libraries[0..placed]) |*item| item.Image.deinit();
    for (graph.Libraries, biases.Libraries) |library, bias| {
        libraries[placed] = try elf.validate.dynamic.parse(allocator, library.Bytes, bias, .Library, policy);
        const layout = &libraries[placed];
        placed += 1;
        if (layout.Image.Pages > remaining) return error.ImageTooLarge;
        remaining -= layout.Image.Pages;
        try addImage(allocator, &intervals, layout);
    }
    try checkSeparation(intervals.items);
    return .{
        .Allocator = allocator,
        .Executable = executable,
        .Libraries = libraries,
        .Pages = policy.MaximumPages - remaining,
    };
}

fn checkReservations(reserved: []const Interval, policy: Policy) LayoutError!void {
    for (reserved) |range| {
        if (range.Start < policy.MinimumAddress or range.Start >= range.End or range.End > policy.MaximumAddress + 1 or
            (range.Start | range.End) & sizes.PAGE_MASK != 0) return error.InvalidReservation;
    }
}

fn addImage(allocator: std.mem.Allocator, intervals: *std.ArrayList(Interval), layout: *const Layout) LayoutError!void {
    try intervals.ensureUnusedCapacity(allocator, layout.Image.Ranges.len);
    for (layout.Image.Ranges) |range| intervals.appendAssumeCapacity(.{ .Start = range.Start, .End = range.End });
}

fn checkSeparation(intervals: []Interval) LayoutError!void {
    std.mem.sort(Interval, intervals, {}, earlier);
    if (intervals.len < 2) return;
    for (intervals[0 .. intervals.len - 1], intervals[1..]) |previous, next| {
        if (next.Start < previous.End) return error.AddressOverlap;
    }
}

fn earlier(_: void, left: Interval, right: Interval) bool {
    return left.Start < right.Start;
}
