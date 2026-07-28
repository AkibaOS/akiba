//! Drawing Primitives

const graphics = @import("shared").graphics;

const Color = graphics.types.color.Color;
const Quad = graphics.types.geometry.Quad;
const Stripe = graphics.types.geometry.Stripe;
const Surface = graphics.types.surface.Surface;

pub fn putPixel(surface: *Surface, x: i32, y: i32, color: Color) void {
    if (!surface.contains(x, y)) {
        return;
    }
    surface.Base[surface.offset(@intCast(x), @intCast(y))] = color.toPixel(surface.Format);
}

pub fn fillRect(surface: *Surface, x: i32, y: i32, width: i32, height: i32, color: Color) void {
    const pixel = color.toPixel(surface.Format);
    const left = clampLow(x);
    const top = clampLow(y);
    const right = clampHigh(x + width, surface.Width);
    const bottom = clampHigh(y + height, surface.Height);

    var row = top;
    while (row < bottom) : (row += 1) {
        const row_offset = surface.offset(0, @intCast(row));
        var column = left;
        while (column < right) : (column += 1) {
            surface.Base[row_offset + @as(usize, @intCast(column))] = pixel;
        }
    }
}

pub fn clear(surface: *Surface, color: Color) void {
    fillRect(surface, 0, 0, @intCast(surface.Width), @intCast(surface.Height), color);
}

pub fn drawHorizontalLine(surface: *Surface, x: i32, y: i32, length: i32, thickness: i32, color: Color) void {
    fillRect(surface, x, y, length, thickness, color);
}

pub fn drawVerticalLine(surface: *Surface, x: i32, y: i32, length: i32, thickness: i32, color: Color) void {
    fillRect(surface, x, y, thickness, length, color);
}

pub fn fillQuad(surface: *Surface, quad: Quad, color: Color, stripe: ?Stripe) void {
    var top = quad[0].Y;
    var bottom = quad[0].Y;
    for (quad) |point| {
        if (point.Y < top) top = point.Y;
        if (point.Y > bottom) bottom = point.Y;
    }

    top = clampLow(top);
    bottom = clampHigh(bottom + 1, surface.Height);

    const pixel = color.toPixel(surface.Format);

    var row = top;
    while (row < bottom) : (row += 1) {
        if (stripe) |pattern| {
            if (@mod(row, pattern.Period) < pattern.Gap) {
                continue;
            }
        }

        const span = spanAt(quad, row) orelse continue;
        const left = clampLow(span.Left);
        const right = clampHigh(span.Right + 1, surface.Width);

        const row_offset = surface.offset(0, @intCast(row));
        var column = left;
        while (column < right) : (column += 1) {
            surface.Base[row_offset + @as(usize, @intCast(column))] = pixel;
        }
    }
}

pub fn copyRect(
    surface: *Surface,
    source_x: u32,
    source_y: u32,
    destination_x: u32,
    destination_y: u32,
    width: u32,
    height: u32,
) void {
    if (source_y < destination_y) {
        var row: u32 = height;
        while (row > 0) {
            row -= 1;
            copyRow(surface, source_x, source_y + row, destination_x, destination_y + row, width);
        }
        return;
    }

    var row: u32 = 0;
    while (row < height) : (row += 1) {
        copyRow(surface, source_x, source_y + row, destination_x, destination_y + row, width);
    }
}

fn copyRow(
    surface: *Surface,
    source_x: u32,
    source_y: u32,
    destination_x: u32,
    destination_y: u32,
    width: u32,
) void {
    const source = surface.offset(source_x, source_y);
    const destination = surface.offset(destination_x, destination_y);

    if (source_x < destination_x) {
        var column: u32 = width;
        while (column > 0) {
            column -= 1;
            surface.Base[destination + column] = surface.Base[source + column];
        }
        return;
    }

    var column: u32 = 0;
    while (column < width) : (column += 1) {
        surface.Base[destination + column] = surface.Base[source + column];
    }
}

const Span = struct {
    Left: i32,
    Right: i32,
};

fn spanAt(quad: Quad, row: i32) ?Span {
    var left: i32 = 0;
    var right: i32 = 0;
    var found = false;

    var edge: usize = 0;
    while (edge < quad.len) : (edge += 1) {
        const first = quad[edge];
        const second = quad[(edge + 1) % quad.len];
        if (first.Y == second.Y) {
            continue;
        }

        const upper = if (first.Y < second.Y) first else second;
        const lower = if (first.Y < second.Y) second else first;
        if (row < upper.Y or row >= lower.Y) {
            continue;
        }

        const run: i64 = lower.X - upper.X;
        const rise: i64 = lower.Y - upper.Y;
        const crossing: i32 = upper.X + @as(i32, @intCast(@divTrunc(run * (row - upper.Y), rise)));

        if (!found) {
            left = crossing;
            right = crossing;
            found = true;
        } else {
            if (crossing < left) left = crossing;
            if (crossing > right) right = crossing;
        }
    }

    if (!found) {
        return null;
    }
    return Span{ .Left = left, .Right = right };
}

fn clampLow(value: i32) i32 {
    return if (value < 0) 0 else value;
}

fn clampHigh(value: i32, limit: u32) i32 {
    const bound: i32 = @intCast(limit);
    return if (value > bound) bound else value;
}
