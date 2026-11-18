//! Glyph Outline In Font Units

const std = @import("std");

const font = @import("shared").font;

const FontError = font.errors.font.FontError;

pub const Point = struct {
    X: i32,
    Y: i32,
    OnCurve: bool,
};

pub const ContourRange = struct {
    Start: usize,
    End: usize,
};

pub const Outline = struct {
    Points: []Point = &.{},
    ContourEnds: []usize = &.{},
    PointCount: usize = 0,
    ContourCount: usize = 0,

    pub fn reset(self: *Outline) void {
        self.PointCount = 0;
        self.ContourCount = 0;
    }

    pub fn contourRange(self: *const Outline, contour: usize) ContourRange {
        const start = if (contour == 0) 0 else self.ContourEnds[contour - 1] +| 1;
        return .{ .Start = start, .End = self.ContourEnds[contour] };
    }
};

pub const GlyphBuffer = struct {
    Shape: Outline = .{},
    Flags: []u8 = &.{},
    Allocator: ?std.mem.Allocator = null,

    pub fn initAllocating(allocator: std.mem.Allocator) GlyphBuffer {
        return .{ .Allocator = allocator };
    }

    pub fn initFixed(points: []Point, contours: []usize, flags: []u8) GlyphBuffer {
        return .{ .Shape = .{ .Points = points, .ContourEnds = contours }, .Flags = flags };
    }

    pub fn deinit(self: *GlyphBuffer) void {
        if (self.Allocator) |allocator| {
            allocator.free(self.Shape.Points);
            allocator.free(self.Shape.ContourEnds);
            allocator.free(self.Flags);
        }
        self.* = .{};
    }

    pub fn reserve(self: *GlyphBuffer, points: usize, contours: usize, flags: usize) FontError!void {
        try ensureCapacity(Point, self.Allocator, &self.Shape.Points, self.Shape.PointCount, points);
        try ensureCapacity(usize, self.Allocator, &self.Shape.ContourEnds, self.Shape.ContourCount, contours);
        try ensureCapacity(u8, self.Allocator, &self.Flags, 0, flags);
    }
};

fn ensureCapacity(comptime Element: type, allocator: ?std.mem.Allocator, storage: *[]Element, used: usize, needed: usize) FontError!void {
    if (needed <= storage.*.len) return;
    const memory = allocator orelse return FontError.ScratchExhausted;
    var list: std.ArrayList(Element) = .{ .items = storage.*[0..used], .capacity = storage.*.len };
    try list.ensureTotalCapacity(memory, needed);
    storage.* = list.allocatedSlice();
}
