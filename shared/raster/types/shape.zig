//! Flattened Shape

const raster = @import("shared").raster;

const Edge = raster.types.edge.Edge;
const RasterError = raster.errors.raster.RasterError;

const limits = raster.constants.limits;

pub const Shape = struct {
    Edges: [limits.MAX_EDGES]Edge,
    EdgeCount: u16,
    MinX: i32,
    MinY: i32,
    MaxX: i32,
    MaxY: i32,

    pub fn reset(self: *Shape) void {
        self.EdgeCount = 0;
        self.MinX = 0x7FFFFFFF;
        self.MinY = 0x7FFFFFFF;
        self.MaxX = -0x7FFFFFFF;
        self.MaxY = -0x7FFFFFFF;
    }

    pub fn isEmpty(self: *const Shape) bool {
        return self.EdgeCount == 0;
    }

    pub fn addEdge(self: *Shape, x0: i32, y0: i32, x1: i32, y1: i32) RasterError!void {
        self.include(x0, y0);
        self.include(x1, y1);

        if (y0 == y1) {
            return;
        }
        if (self.EdgeCount >= limits.MAX_EDGES) {
            return RasterError.TooManyEdges;
        }

        self.Edges[self.EdgeCount] = if (y0 < y1)
            Edge{ .X0 = x0, .Y0 = y0, .X1 = x1, .Y1 = y1, .Direction = 1 }
        else
            Edge{ .X0 = x1, .Y0 = y1, .X1 = x0, .Y1 = y0, .Direction = -1 };

        self.EdgeCount += 1;
    }

    fn include(self: *Shape, x: i32, y: i32) void {
        if (x < self.MinX) self.MinX = x;
        if (x > self.MaxX) self.MaxX = x;
        if (y < self.MinY) self.MinY = y;
        if (y > self.MaxY) self.MaxY = y;
    }
};
