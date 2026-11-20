//! Independent Minimal TrueType Fixtures

const constants = @import("tests").fast.constants.render;
const encoding = @import("tests").fast.shared.sfnt.fixture;
const font = @import("shared").font;
const types = @import("tests").fast.types.render;

const Face = font.types.face.font.Face;
const GlyphFixture = types.GlyphFixture;
const SFNTFixture = types.SFNTFixture;

pub fn minimal() SFNTFixture {
    var head: [54]u8 = @splat(0);
    encoding.writeU32(&head, 0, constants.SFNT_VERSION);
    encoding.writeU32(&head, 12, constants.HEAD_MAGIC);
    encoding.writeU16(&head, 18, 64);
    encoding.writeU16(&head, 38, @bitCast(@as(i16, -16)));
    encoding.writeU16(&head, 40, 48);
    encoding.writeU16(&head, 42, 64);
    encoding.writeU16(&head, 46, 8);
    encoding.writeU16(&head, 48, 2);
    var maxp: [32]u8 = @splat(0);
    encoding.writeU32(&maxp, 0, constants.SFNT_VERSION);
    encoding.writeU16(&maxp, 4, 4);
    encoding.writeU16(&maxp, 6, 4);
    encoding.writeU16(&maxp, 8, 1);
    encoding.writeU16(&maxp, 10, 4);
    encoding.writeU16(&maxp, 12, 1);
    encoding.writeU16(&maxp, 14, 2);
    encoding.writeU16(&maxp, 28, 1);
    encoding.writeU16(&maxp, 30, 1);
    var hhea: [36]u8 = @splat(0);
    encoding.writeU32(&hhea, 0, constants.SFNT_VERSION);
    encoding.writeU16(&hhea, 4, 48);
    encoding.writeU16(&hhea, 6, @bitCast(@as(i16, -16)));
    encoding.writeU16(&hhea, 10, 64);
    encoding.writeU16(&hhea, 12, @bitCast(@as(i16, -4)));
    encoding.writeU16(&hhea, 16, 48);
    encoding.writeU16(&hhea, 18, 1);
    encoding.writeU16(&hhea, 34, 2);
    return encoding.pack(&.{
        .{ .Tag = constants.HEAD_TAG, .Bytes = &head },
        .{ .Tag = constants.MAXP_TAG, .Bytes = &maxp },
        .{ .Tag = constants.HHEA_TAG, .Bytes = &hhea },
        .{ .Tag = constants.HMTX_TAG, .Bytes = &constants.HMTX },
        .{ .Tag = constants.LOCA_TAG, .Bytes = &constants.LOCA },
        .{ .Tag = constants.GLYF_TAG, .Bytes = &constants.GLYF },
        .{ .Tag = constants.CMAP_TAG, .Bytes = &constants.CMAP },
    });
}

pub fn appendGlyph(storage: *GlyphFixture, face: *Face, bytes: []const u8) void {
    @memset(&storage.Data, 0);
    @memset(&storage.Loca, 0);
    @memcpy(storage.Data[0..face.Glyf.len], face.Glyf);
    @memcpy(storage.Data[face.Glyf.len..][0..bytes.len], bytes);
    const location_length = (@as(usize, face.GlyphCount) + 1) * 2;
    @memcpy(storage.Loca[0..location_length], face.Loca[0..location_length]);
    const length = face.Glyf.len + bytes.len;
    encoding.writeU16(&storage.Loca, location_length, @intCast(length / 2));
    face.Glyf = storage.Data[0..length];
    face.Loca = storage.Loca[0 .. location_length + 2];
    face.GlyphCount += 1;
}

pub fn componentChain(storage: *GlyphFixture, face: *Face, depth: u8) void {
    @memset(&storage.Data, 0);
    @memset(&storage.Loca, 0);
    var index: usize = 0;
    while (index < depth) : (index += 1) {
        const offset = index * 18;
        encoding.writeU16(&storage.Loca, index * 2, @intCast(offset / 2));
        encoding.writeU16(&storage.Data, offset, 0xFFFF);
        encoding.writeU16(&storage.Data, offset + 10, 0x0003);
        encoding.writeU16(&storage.Data, offset + 12, @intCast(index + 1));
    }
    const leaf = @as(usize, depth) * 18;
    encoding.writeU16(&storage.Loca, @as(usize, depth) * 2, @intCast(leaf / 2));
    @memcpy(storage.Data[leaf..][0..constants.RECTANGLE_GLYPH.len], &constants.RECTANGLE_GLYPH);
    const length = leaf + constants.RECTANGLE_GLYPH.len;
    encoding.writeU16(&storage.Loca, (@as(usize, depth) + 1) * 2, @intCast(length / 2));
    face.Glyf = storage.Data[0..length];
    face.Loca = storage.Loca[0 .. (@as(usize, depth) + 2) * 2];
    face.GlyphCount = @as(u16, depth) + 1;
    face.IndexToLocationFormat = 0;
}
