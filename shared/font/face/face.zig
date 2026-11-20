//! Face Loading

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Directory = sfnt.types.directory.Directory;
const Face = font.types.face.font.Face;
const FontError = font.errors.font.FontError;
const Reader = sfnt.types.reader.Reader;

const limits = font.constants.limits;
const metrics = font.constants.metrics.layout;
const tags = sfnt.constants.tags;

pub fn load(data: []const u8) FontError!Face {
    const directory = try Directory.parse(data);

    const head = try directory.require(tags.HEAD);
    const maxp = try directory.require(tags.MAXP);
    const hhea = try directory.require(tags.HHEA);

    if (head.len < limits.HEAD_SIZE or maxp.len < limits.MAXP_SIZE or hhea.len < limits.HHEA_SIZE) {
        return FontError.UnexpectedEnd;
    }

    var head_reader = Reader.initialize(head);
    try head_reader.seek(limits.OFFSET_UNITS_PER_EM);
    const units_per_em = try head_reader.readU16();
    if (units_per_em < limits.MIN_UNITS_PER_EM or units_per_em > limits.MAX_UNITS_PER_EM) {
        return FontError.InvalidUnitsPerEm;
    }
    try head_reader.seek(limits.OFFSET_INDEX_TO_LOCATION);
    const index_to_location = try head_reader.readI16();

    var maxp_reader = Reader.initialize(maxp);
    try maxp_reader.seek(limits.OFFSET_GLYPH_COUNT);
    const glyph_count = try maxp_reader.readU16();
    if (glyph_count == 0) return FontError.InvalidGlyphCount;

    var hhea_reader = Reader.initialize(hhea);
    try hhea_reader.seek(limits.OFFSET_ASCENDER);
    const ascender = try hhea_reader.readI16();
    const descender = try hhea_reader.readI16();
    const line_gap = try hhea_reader.readI16();
    try hhea_reader.seek(limits.OFFSET_LONG_METRIC_COUNT);
    const long_metric_count = try hhea_reader.readU16();
    if (long_metric_count == 0 or long_metric_count > glyph_count) return FontError.InvalidMetrics;

    const glyf = try directory.require(tags.GLYF);
    const loca = try directory.require(tags.LOCA);
    try font.location.validate(loca, index_to_location, glyph_count, glyf.len);

    const hmtx = try directory.require(tags.HMTX);
    const metric_length = @as(usize, long_metric_count) * metrics.LONG_METRIC_SIZE +
        @as(usize, glyph_count - long_metric_count) * @sizeOf(i16);
    if (hmtx.len < metric_length) return FontError.UnexpectedEnd;

    return .{
        .Directory = directory,
        .UnitsPerEm = units_per_em,
        .GlyphCount = glyph_count,
        .IndexToLocationFormat = index_to_location,
        .Ascender = ascender,
        .Descender = descender,
        .LineGap = line_gap,
        .LongMetricCount = long_metric_count,
        .Glyf = glyf,
        .Loca = loca,
        .Hmtx = hmtx,
        .Charmap = try font.charmap.selectForFace(try directory.require(tags.CMAP), glyph_count),
    };
}
