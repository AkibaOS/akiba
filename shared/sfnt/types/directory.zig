//! SFNT Table Directory

const sfnt = @import("shared").sfnt;

const constants = sfnt.constants;

const ParseError = sfnt.errors.parse.ParseError;
const Reader = sfnt.types.reader.Reader;

const limits = constants.limits;
const tags = constants.tags;

pub const Directory = struct {
    Data: []const u8,
    Records: []const u8,
    Count: u16,

    pub fn parse(data: []const u8) ParseError!Directory {
        var reader = Reader.initialize(data);

        const version = try reader.readU32();
        if (version == tags.VERSION_COLLECTION) {
            return ParseError.UnsupportedCollection;
        }
        if (version == tags.VERSION_OPENTYPE) {
            return ParseError.UnsupportedOutlines;
        }
        if (version != tags.VERSION_TRUETYPE and version != tags.VERSION_TRUE) {
            return ParseError.InvalidSignature;
        }

        const count = try reader.readU16();
        try reader.skip(limits.OFFSET_TABLE_SIZE - @sizeOf(u32) - @sizeOf(u16));

        var index: u16 = 0;
        while (index < count) : (index += 1) {
            _ = try reader.readU32();
            _ = try reader.readU32();
            const offset = try reader.readU32();
            const length = try reader.readU32();

            if (offset > data.len or length > data.len - offset) {
                return ParseError.TableOutOfBounds;
            }
        }

        return .{
            .Data = data,
            .Records = data[limits.OFFSET_TABLE_SIZE..reader.Offset],
            .Count = count,
        };
    }

    pub fn find(self: *const Directory, tag: u32) ?[]const u8 {
        var reader = Reader.initialize(self.Records);
        var index: u16 = 0;
        while (index < self.Count) : (index += 1) {
            const entry_tag = reader.readU32() catch return null;
            _ = reader.readU32() catch return null;
            const offset = reader.readU32() catch return null;
            const length = reader.readU32() catch return null;
            if (entry_tag == tag) {
                if (offset > self.Data.len or length > self.Data.len - offset) return null;
                return self.Data[offset..][0..length];
            }
        }
        return null;
    }

    pub fn require(self: *const Directory, tag: u32) ParseError![]const u8 {
        return self.find(tag) orelse ParseError.TableMissing;
    }
};
