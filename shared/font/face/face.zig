//! Face Loading

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const constants = font.constants;

const Directory = sfnt.directory.Directory;
const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const Reader = sfnt.types.reader.Reader;

const limits = constants.limits;
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
    try head_reader.seek(limits.OFFSET_INDEX_TO_LOCATION);
    const index_to_location = try head_reader.readI16();

    var maxp_reader = Reader.initialize(maxp);
    try maxp_reader.seek(limits.OFFSET_GLYPH_COUNT);
    const glyph_count = try maxp_reader.readU16();
    try maxp_reader.seek(limits.OFFSET_MAX_POINTS);
    const max_points = try maxp_reader.readU16();
    const max_contours = try maxp_reader.readU16();
    try maxp_reader.seek(limits.OFFSET_MAX_COMPOSITE_POINTS);
    const max_composite_points = try maxp_reader.readU16();

    if (max_points > limits.MAX_POINTS or max_composite_points > limits.MAX_POINTS) {
        return FontError.OutlineTooComplex;
    }
    if (max_contours > limits.MAX_CONTOURS) {
        return FontError.OutlineTooComplex;
    }

    var hhea_reader = Reader.initialize(hhea);
    try hhea_reader.seek(limits.OFFSET_ASCENDER);
    const ascender = try hhea_reader.readI16();
    const descender = try hhea_reader.readI16();
    const line_gap = try hhea_reader.readI16();
    try hhea_reader.seek(limits.OFFSET_LONG_METRIC_COUNT);
    const long_metric_count = try hhea_reader.readU16();

    return Face{
        .Directory = directory,
        .UnitsPerEm = units_per_em,
        .GlyphCount = glyph_count,
        .IndexToLocationFormat = index_to_location,
        .Ascender = ascender,
        .Descender = descender,
        .LineGap = line_gap,
        .LongMetricCount = long_metric_count,
        .Glyf = try directory.require(tags.GLYF),
        .Loca = try directory.require(tags.LOCA),
        .Hmtx = try directory.require(tags.HMTX),
        .Charmap = try font.charmap.select(try directory.require(tags.CMAP)),
    };
}
