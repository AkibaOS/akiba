//! Glyph Outline Extraction

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const constants = font.constants.glyf;

const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const GlyphBuffer = font.types.outline.GlyphBuffer;
const Point = font.types.outline.Point;
const Reader = sfnt.types.reader.Reader;

const limits = font.constants.limits;

const Transform = struct {
    A: i32,
    B: i32,
    C: i32,
    D: i32,
    Dx: i32,
    Dy: i32,

    fn identity() Transform {
        return Transform{
            .A = constants.TRANSFORM_ONE,
            .B = 0,
            .C = 0,
            .D = constants.TRANSFORM_ONE,
            .Dx = 0,
            .Dy = 0,
        };
    }

    fn apply(self: Transform, x: i32, y: i32) Point {
        return Point{
            .X = ((self.A * x + self.C * y) >> constants.TRANSFORM_FRACTION_BITS) + self.Dx,
            .Y = ((self.B * x + self.D * y) >> constants.TRANSFORM_FRACTION_BITS) + self.Dy,
            .OnCurve = false,
        };
    }

    fn compose(parent: Transform, child: Transform) Transform {
        const shift = constants.TRANSFORM_FRACTION_BITS;
        return Transform{
            .A = (parent.A * child.A + parent.C * child.B) >> shift,
            .B = (parent.B * child.A + parent.D * child.B) >> shift,
            .C = (parent.A * child.C + parent.C * child.D) >> shift,
            .D = (parent.B * child.C + parent.D * child.D) >> shift,
            .Dx = ((parent.A * child.Dx + parent.C * child.Dy) >> shift) + parent.Dx,
            .Dy = ((parent.B * child.Dx + parent.D * child.Dy) >> shift) + parent.Dy,
        };
    }
};

pub fn load(face: *const Face, glyph_id: u16, buffer: *GlyphBuffer) FontError!void {
    buffer.Shape.reset();
    try appendGlyph(face, glyph_id, Transform.identity(), 0, buffer);
}

fn appendGlyph(
    face: *const Face,
    glyph_id: u16,
    transform: Transform,
    depth: u8,
    buffer: *GlyphBuffer,
) FontError!void {
    if (depth > limits.MAX_COMPONENT_DEPTH) {
        return FontError.ComponentDepthExceeded;
    }

    const bounds = try glyphBounds(face, glyph_id);
    if (bounds.End <= bounds.Start) {
        return;
    }
    if (bounds.End > face.Glyf.len) {
        return FontError.TableOutOfBounds;
    }

    const data = face.Glyf[bounds.Start..bounds.End];
    var reader = Reader.initialize(data);
    const contour_count = try reader.readI16();
    try reader.skip(8);

    if (contour_count >= 0) {
        try appendSimpleGlyph(&reader, @intCast(contour_count), transform, buffer);
        return;
    }

    try appendCompositeGlyph(face, &reader, transform, depth, buffer);
}

fn glyphBounds(face: *const Face, glyph_id: u16) FontError!struct { Start: usize, End: usize } {
    if (glyph_id >= face.GlyphCount) {
        return FontError.GlyphOutOfRange;
    }

    var reader = Reader.initialize(face.Loca);

    if (face.IndexToLocationFormat == 0) {
        try reader.seek(@as(usize, glyph_id) * 2);
        const start = @as(usize, try reader.readU16()) * 2;
        const end = @as(usize, try reader.readU16()) * 2;
        return .{ .Start = start, .End = end };
    }

    try reader.seek(@as(usize, glyph_id) * 4);
    const start = try reader.readU32();
    const end = try reader.readU32();
    return .{ .Start = start, .End = end };
}

fn appendSimpleGlyph(
    reader: *Reader,
    contour_count: u16,
    transform: Transform,
    buffer: *GlyphBuffer,
) FontError!void {
    const base_point = buffer.Shape.PointCount;
    const base_contour = buffer.Shape.ContourCount;

    if (base_contour + contour_count > limits.MAX_CONTOURS) {
        return FontError.OutlineTooComplex;
    }

    var contour: u16 = 0;
    var last_end: u16 = 0;
    while (contour < contour_count) : (contour += 1) {
        last_end = try reader.readU16();
        buffer.Shape.ContourEnds[base_contour + contour] = base_point + last_end;
    }

    const point_count: u16 = if (contour_count == 0) 0 else last_end + 1;
    if (@as(usize, base_point) + point_count > limits.MAX_POINTS) {
        return FontError.OutlineTooComplex;
    }

    const instruction_length = try reader.readU16();
    try reader.skip(instruction_length);

    var index: u16 = 0;
    while (index < point_count) {
        const flag = try reader.readU8();
        buffer.Flags[base_point + index] = flag;
        index += 1;

        if ((flag & constants.REPEAT_FLAG) != 0) {
            var repeats = try reader.readU8();
            while (repeats > 0 and index < point_count) : (repeats -= 1) {
                buffer.Flags[base_point + index] = flag;
                index += 1;
            }
        }
    }

    var x: i32 = 0;
    index = 0;
    while (index < point_count) : (index += 1) {
        const flag = buffer.Flags[base_point + index];
        if ((flag & constants.X_SHORT_VECTOR) != 0) {
            const delta: i32 = try reader.readU8();
            x += if ((flag & constants.X_SAME_OR_POSITIVE) != 0) delta else -delta;
        } else if ((flag & constants.X_SAME_OR_POSITIVE) == 0) {
            x += try reader.readI16();
        }
        buffer.Shape.Points[base_point + index].X = x;
    }

    var y: i32 = 0;
    index = 0;
    while (index < point_count) : (index += 1) {
        const flag = buffer.Flags[base_point + index];
        if ((flag & constants.Y_SHORT_VECTOR) != 0) {
            const delta: i32 = try reader.readU8();
            y += if ((flag & constants.Y_SAME_OR_POSITIVE) != 0) delta else -delta;
        } else if ((flag & constants.Y_SAME_OR_POSITIVE) == 0) {
            y += try reader.readI16();
        }
        buffer.Shape.Points[base_point + index].Y = y;
    }

    index = 0;
    while (index < point_count) : (index += 1) {
        const slot = &buffer.Shape.Points[base_point + index];
        const placed = transform.apply(slot.X, slot.Y);
        slot.X = placed.X;
        slot.Y = placed.Y;
        slot.OnCurve = (buffer.Flags[base_point + index] & constants.ON_CURVE_POINT) != 0;
    }

    buffer.Shape.PointCount = base_point + point_count;
    buffer.Shape.ContourCount = base_contour + contour_count;
}

fn appendCompositeGlyph(
    face: *const Face,
    reader: *Reader,
    transform: Transform,
    depth: u8,
    buffer: *GlyphBuffer,
) FontError!void {
    while (true) {
        const flags = try reader.readU16();
        const component_id = try reader.readU16();

        var dx: i32 = 0;
        var dy: i32 = 0;

        if ((flags & constants.ARGS_ARE_WORDS) != 0) {
            const first = try reader.readI16();
            const second = try reader.readI16();
            if ((flags & constants.ARGS_ARE_XY_VALUES) != 0) {
                dx = first;
                dy = second;
            }
        } else {
            const first: i8 = @bitCast(try reader.readU8());
            const second: i8 = @bitCast(try reader.readU8());
            if ((flags & constants.ARGS_ARE_XY_VALUES) != 0) {
                dx = first;
                dy = second;
            }
        }

        var component = Transform.identity();
        component.Dx = dx;
        component.Dy = dy;

        if ((flags & constants.HAS_SCALE) != 0) {
            const scale = try readTransformValue(reader);
            component.A = scale;
            component.D = scale;
        } else if ((flags & constants.HAS_X_AND_Y_SCALE) != 0) {
            component.A = try readTransformValue(reader);
            component.D = try readTransformValue(reader);
        } else if ((flags & constants.HAS_TWO_BY_TWO) != 0) {
            component.A = try readTransformValue(reader);
            component.B = try readTransformValue(reader);
            component.C = try readTransformValue(reader);
            component.D = try readTransformValue(reader);
        }

        try appendGlyph(face, component_id, Transform.compose(transform, component), depth + 1, buffer);

        if ((flags & constants.MORE_COMPONENTS) == 0) {
            return;
        }
    }
}

fn readTransformValue(reader: *Reader) FontError!i32 {
    const raw: i16 = @bitCast(try reader.readU16());
    return raw;
}
