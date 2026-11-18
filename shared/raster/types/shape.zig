//! Flattened Shape

const std = @import("std");

const raster = @import("shared").raster;

const Edge = raster.types.edge.Edge;
const RasterError = raster.errors.raster.RasterError;

pub const Shape = struct {
    Edges: []Edge = &.{},
    EdgeCount: usize = 0,
    MinX: i32 = std.math.maxInt(i32),
    MinY: i32 = std.math.maxInt(i32),
    MaxX: i32 = std.math.minInt(i32),
    MaxY: i32 = std.math.minInt(i32),
    Allocator: ?std.mem.Allocator = null,

    pub fn initAllocating(allocator: std.mem.Allocator) Shape {
        return .{ .Allocator = allocator };
    }

    pub fn initFixed(edges: []Edge) Shape {
        return .{ .Edges = edges };
    }

    pub fn deinit(self: *Shape) void {
        if (self.Allocator) |allocator| allocator.free(self.Edges);
        self.* = .{};
    }

    pub fn reset(self: *Shape) void {
        self.EdgeCount = 0;
        self.MinX = std.math.maxInt(i32);
        self.MinY = std.math.maxInt(i32);
        self.MaxX = std.math.minInt(i32);
        self.MaxY = std.math.minInt(i32);
    }

    pub fn isEmpty(self: *const Shape) bool {
        return self.EdgeCount == 0;
    }

    pub fn addEdge(self: *Shape, x0: i32, y0: i32, x1: i32, y1: i32) RasterError!void {
        if (y0 != y1) {
            if (self.EdgeCount == self.Edges.len) try self.grow();
            self.Edges[self.EdgeCount] = if (y0 < y1)
                Edge{ .X0 = x0, .Y0 = y0, .X1 = x1, .Y1 = y1, .Direction = 1 }
            else
                Edge{ .X0 = x1, .Y0 = y1, .X1 = x0, .Y1 = y0, .Direction = -1 };
            self.EdgeCount += 1;
        }

        self.MinX = @min(self.MinX, x0, x1);
        self.MinY = @min(self.MinY, y0, y1);
        self.MaxX = @max(self.MaxX, x0, x1);
        self.MaxY = @max(self.MaxY, y0, y1);
    }

    fn grow(self: *Shape) RasterError!void {
        const allocator = self.Allocator orelse return RasterError.ScratchExhausted;
        var list: std.ArrayList(Edge) = .{ .items = self.Edges[0..self.EdgeCount], .capacity = self.Edges.len };
        try list.ensureUnusedCapacity(allocator, 1);
        self.Edges = list.allocatedSlice();
    }
};
