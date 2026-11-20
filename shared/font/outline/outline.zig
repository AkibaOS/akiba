//! Glyph Outline Extraction

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Face = font.types.face.font.Face;
const FontError = font.errors.font.FontError;
const GlyphBuffer = font.types.outline.contour.GlyphBuffer;
const Reader = sfnt.types.reader.Reader;
const Transform = font.types.transform.Transform;

const constants = font.constants.glyf;
const limits = font.constants.limits;

pub fn load(face: *const Face, glyph_id: u16, buffer: *GlyphBuffer) FontError!void {
    buffer.Shape.reset();
    errdefer buffer.Shape.reset();
    var visits: usize = limits.MAX_COMPONENT_VISITS;
    try appendGlyph(face, glyph_id, Transform.identity(), 0, &visits, buffer);
}

fn appendGlyph(face: *const Face, glyph_id: u16, transform: Transform, depth: u8, visits: *usize, buffer: *GlyphBuffer) FontError!void {
    if (depth > limits.MAX_COMPONENT_DEPTH) return FontError.ComponentDepthExceeded;
    if (visits.* == 0) return FontError.OutlineTooComplex;
    visits.* -= 1;

    const bounds = try font.location.bounds(face, glyph_id);
    if (bounds.Start == bounds.End) return;

    var reader = Reader.initialize(face.Glyf[bounds.Start..bounds.End]);
    const contour_count = try reader.readI16();
    try reader.skip(constants.GLYPH_BOUNDS_BYTES);

    if (contour_count >= 0) {
        if (contour_count == 0 and reader.remaining() == 0) return;
        return appendSimpleGlyph(&reader, @intCast(contour_count), transform, buffer);
    }
    return appendCompositeGlyph(face, &reader, transform, depth, visits, buffer);
}

fn appendSimpleGlyph(reader: *Reader, contour_count: usize, transform: Transform, buffer: *GlyphBuffer) FontError!void {
    const base_point = buffer.Shape.PointCount;
    const base_contour = buffer.Shape.ContourCount;
    var contour_reader = reader.*;
    const point_count = try readPointCount(reader, contour_count);
    try skipInstructions(reader);
    if (point_count > limits.MAX_EXPANDED_POINTS - base_point) return FontError.OutlineTooComplex;

    var data_reader = reader.*;
    try validatePointData(&data_reader, point_count);
    try buffer.reserve(base_point + point_count, base_contour + contour_count, point_count);

    for (0..contour_count) |contour| {
        buffer.Shape.ContourEnds[base_contour + contour] = base_point + @as(usize, try contour_reader.readU16());
    }
    const flags = buffer.Flags[0..point_count];
    try expandFlags(reader, flags);
    const points = buffer.Shape.Points[base_point..][0..point_count];
    var coordinate: i32 = 0;
    for (points, flags) |*point, flag| {
        coordinate += try readDelta(reader, flag, constants.X_SHORT_VECTOR, constants.X_SAME_OR_POSITIVE);
        point.X = coordinate;
    }
    coordinate = 0;
    for (points, flags) |*point, flag| {
        coordinate += try readDelta(reader, flag, constants.Y_SHORT_VECTOR, constants.Y_SAME_OR_POSITIVE);
        point.* = try transform.apply(point.X, coordinate);
        point.OnCurve = (flag & constants.ON_CURVE_POINT) != 0;
    }

    buffer.Shape.PointCount = base_point + point_count;
    buffer.Shape.ContourCount = base_contour + contour_count;
}

fn readPointCount(reader: *Reader, contour_count: usize) FontError!usize {
    if (contour_count > reader.remaining() / @sizeOf(u16)) return FontError.UnexpectedEnd;
    var total: usize = 0;
    for (0..contour_count) |_| {
        const next = @as(usize, try reader.readU16()) + 1;
        if (next <= total) return FontError.InvalidOutline;
        total = next;
    }
    return total;
}

fn validatePointData(reader: *Reader, point_count: usize) FontError!void {
    var remaining = point_count;
    var coordinate_bytes: usize = 0;
    while (remaining != 0) {
        const flag = try reader.readU8();
        const count = try flagCount(reader, flag, remaining);
        coordinate_bytes += count * (deltaBytes(flag, constants.X_SHORT_VECTOR, constants.X_SAME_OR_POSITIVE) +
            deltaBytes(flag, constants.Y_SHORT_VECTOR, constants.Y_SAME_OR_POSITIVE));
        remaining -= count;
    }
    if (coordinate_bytes > reader.remaining()) return FontError.UnexpectedEnd;
}

fn expandFlags(reader: *Reader, flags: []u8) FontError!void {
    var written: usize = 0;
    while (written < flags.len) {
        const flag = try reader.readU8();
        const count = try flagCount(reader, flag, flags.len - written);
        @memset(flags[written..][0..count], flag);
        written += count;
    }
}

fn flagCount(reader: *Reader, flag: u8, remaining: usize) FontError!usize {
    const count = if ((flag & constants.REPEAT_FLAG) != 0) @as(usize, try reader.readU8()) + 1 else 1;
    if (count > remaining) return FontError.InvalidOutline;
    return count;
}

fn deltaBytes(flag: u8, short: u8, same_or_positive: u8) usize {
    if ((flag & short) != 0) return @sizeOf(u8);
    return if ((flag & same_or_positive) == 0) @sizeOf(i16) else 0;
}

fn readDelta(reader: *Reader, flag: u8, short: u8, same_or_positive: u8) FontError!i32 {
    const same = (flag & same_or_positive) != 0;
    if ((flag & short) != 0) {
        const value: i32 = try reader.readU8();
        return if (same) value else -value;
    }
    return if (same) 0 else try reader.readI16();
}

fn appendCompositeGlyph(face: *const Face, reader: *Reader, transform: Transform, depth: u8, visits: *usize, buffer: *GlyphBuffer) FontError!void {
    var has_instructions = false;
    while (true) {
        const flags = try reader.readU16();
        const component_id = try reader.readU16();
        const component = try readComponentTransform(reader, flags);
        try appendGlyph(face, component_id, try Transform.compose(transform, component), depth + 1, visits, buffer);
        has_instructions = has_instructions or (flags & constants.HAS_INSTRUCTIONS) != 0;
        if ((flags & constants.MORE_COMPONENTS) == 0) break;
    }
    if (has_instructions) try skipInstructions(reader);
}

fn readComponentTransform(reader: *Reader, flags: u16) FontError!Transform {
    if ((flags & constants.ARGS_ARE_XY_VALUES) == 0) return FontError.UnsupportedComponentPlacement;
    if (@popCount(flags & constants.COMPONENT_TRANSFORM_FLAGS) > 1 or
        @popCount(flags & constants.COMPONENT_OFFSET_FLAGS) > 1) return FontError.InvalidOutline;

    const words = (flags & constants.ARGS_ARE_WORDS) != 0;
    const dx = try readComponentOffset(reader, words);
    const dy = try readComponentOffset(reader, words);

    var component = Transform.identity();
    switch (flags & constants.COMPONENT_TRANSFORM_FLAGS) {
        constants.HAS_SCALE => {
            component.A = try reader.readI16();
            component.D = component.A;
        },
        constants.HAS_X_AND_Y_SCALE => {
            component.A = try reader.readI16();
            component.D = try reader.readI16();
        },
        constants.HAS_TWO_BY_TWO => {
            component.A = try reader.readI16();
            component.B = try reader.readI16();
            component.C = try reader.readI16();
            component.D = try reader.readI16();
        },
        else => {},
    }

    try component.setOffset(dx, dy, (flags & constants.SCALED_COMPONENT_OFFSET) != 0);
    return component;
}

fn readComponentOffset(reader: *Reader, words: bool) FontError!i32 {
    if (words) return try reader.readI16();
    return @as(i8, @bitCast(try reader.readU8()));
}

fn skipInstructions(reader: *Reader) FontError!void {
    const length = try reader.readU16();
    try reader.skip(length);
}
