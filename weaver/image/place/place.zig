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
const Shape = image.types.layout.Shape;

pub fn place(allocator: std.mem.Allocator, graph: *const Graph, biases: ?Biases, policy: Policy, reserved: []const Interval) LayoutError!Placement {
    if (biases) |specified| if (specified.Libraries.len != graph.Libraries.len) return error.InvalidPlacement;
    try elf.validate.load.validatePolicy(policy);
    try checkReservations(reserved, policy);
    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    try intervals.appendSlice(allocator, reserved);

    const initial = if (biases) |specified| specified.Executable else try fit(graph.Executable, policy.MinimumAddress, policy, reserved);
    var executable = try elf.validate.dynamic.parse(allocator, graph.Executable, initial, .Executable, policy);
    errdefer executable.Image.deinit();
    try addImage(allocator, &intervals, &executable);
    var remaining = policy.MaximumPages - executable.Image.Pages;
    var floor = executable.Image.Ranges[executable.Image.Ranges.len - 1].End;

    const libraries = try allocator.alloc(Layout, graph.Libraries.len);
    errdefer allocator.free(libraries);
    var placed: usize = 0;
    errdefer for (libraries[0..placed]) |*item| item.Image.deinit();
    for (graph.Libraries, 0..) |library, index| {
        const bias = if (biases) |specified| specified.Libraries[index] else try fit(library.Bytes, floor, policy, reserved);
        libraries[placed] = try elf.validate.dynamic.parse(allocator, library.Bytes, bias, .Library, policy);
        const layout = &libraries[placed];
        placed += 1;
        if (layout.Image.Pages > remaining) return error.ImageTooLarge;
        remaining -= layout.Image.Pages;
        try addImage(allocator, &intervals, layout);
        floor = layout.Image.Ranges[layout.Image.Ranges.len - 1].End;
    }
    try checkSeparation(intervals.items);
    return .{
        .Allocator = allocator,
        .Executable = executable,
        .Graph = graph,
        .Libraries = libraries,
        .Pages = policy.MaximumPages - remaining,
    };
}

fn fit(data: []const u8, floor: u64, policy: Policy, reserved: []const Interval) LayoutError!u64 {
    const image_span = try shape(data);
    var next = floor -| image_span.Span.Start;
    while (true) {
        const bias = try alignAddress(next, image_span.Alignment);
        const start = std.math.add(u64, bias, image_span.Span.Start) catch return error.InvalidPlacement;
        const end = std.math.add(u64, bias, image_span.Span.End) catch return error.InvalidPlacement;
        if (end > policy.MaximumAddress + 1) return error.InvalidPlacement;
        next = bias;
        for (reserved) |region| {
            if (start < region.End and region.Start < end) next = @max(next, region.End - image_span.Span.Start);
        }
        if (next == bias) return bias;
    }
}

fn shape(data: []const u8) LayoutError!Shape {
    const header = try elf.read.header.read(data);
    const programs = try elf.read.programs.read(data, header);
    var result: Shape = .{ .Span = .{ .Start = std.math.maxInt(u64), .End = 0 }, .Alignment = sizes.PAGE_SIZE };
    for (programs) |segment| {
        if (!segment.isLoadable()) continue;
        if (segment.MemorySize == 0 or (segment.Alignment > 1 and !std.math.isPowerOfTwo(segment.Alignment))) return error.InvalidSegment;
        const end = std.math.add(u64, segment.VirtualAddress, segment.MemorySize) catch return error.InvalidSegment;
        result.Span.Start = @min(result.Span.Start, segment.VirtualAddress & ~sizes.PAGE_MASK);
        result.Span.End = @max(result.Span.End, try alignAddress(end, sizes.PAGE_SIZE));
        result.Alignment = @max(result.Alignment, segment.Alignment);
    }
    if (result.Span.End == 0) return error.NoLoadableSegments;
    return result;
}

fn alignAddress(value: u64, alignment: u64) LayoutError!u64 {
    const rounded = std.math.add(u64, value, alignment - 1) catch return error.InvalidPlacement;
    return rounded & ~(alignment - 1);
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
