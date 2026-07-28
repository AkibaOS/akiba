//! SFNT Table Directory

const sfnt = @import("shared").sfnt;

const constants = sfnt.constants;

const ParseError = sfnt.errors.parse.ParseError;
const Reader = sfnt.types.reader.Reader;
const TableRecord = sfnt.types.record.TableRecord;

const limits = constants.limits;
const tags = constants.tags;

pub const Directory = struct {
    Data: []const u8,
    Records: [limits.MAX_TABLES]TableRecord,
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
        if (count > limits.MAX_TABLES) {
            return ParseError.TooManyTables;
        }
        try reader.skip(6);

        var directory = Directory{
            .Data = data,
            .Records = undefined,
            .Count = count,
        };

        var index: u16 = 0;
        while (index < count) : (index += 1) {
            const tag = try reader.readU32();
            _ = try reader.readU32();
            const offset = try reader.readU32();
            const length = try reader.readU32();

            if (offset > data.len or length > data.len - offset) {
                return ParseError.TableOutOfBounds;
            }

            directory.Records[index] = TableRecord{
                .Tag = tag,
                .Offset = offset,
                .Length = length,
            };
        }

        return directory;
    }

    pub fn find(self: *const Directory, tag: u32) ?[]const u8 {
        var index: u16 = 0;
        while (index < self.Count) : (index += 1) {
            const entry = self.Records[index];
            if (entry.Tag == tag) {
                return self.Data[entry.Offset .. entry.Offset + entry.Length];
            }
        }
        return null;
    }

    pub fn require(self: *const Directory, tag: u32) ParseError![]const u8 {
        return self.find(tag) orelse ParseError.TableMissing;
    }
};
