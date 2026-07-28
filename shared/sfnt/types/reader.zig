//! Bounds Checked Big Endian Reader

const sfnt = @import("shared").sfnt;

const ParseError = sfnt.errors.parse.ParseError;

pub const Reader = struct {
    Data: []const u8,
    Offset: usize,

    pub fn initialize(data: []const u8) Reader {
        return Reader{ .Data = data, .Offset = 0 };
    }

    pub fn seek(self: *Reader, offset: usize) ParseError!void {
        if (offset > self.Data.len) {
            return ParseError.UnexpectedEnd;
        }
        self.Offset = offset;
    }

    pub fn skip(self: *Reader, count: usize) ParseError!void {
        try self.seek(self.Offset + count);
    }

    pub fn remaining(self: *const Reader) usize {
        return self.Data.len - self.Offset;
    }

    pub fn readU8(self: *Reader) ParseError!u8 {
        if (self.remaining() < 1) {
            return ParseError.UnexpectedEnd;
        }
        const value = self.Data[self.Offset];
        self.Offset += 1;
        return value;
    }

    pub fn readU16(self: *Reader) ParseError!u16 {
        if (self.remaining() < 2) {
            return ParseError.UnexpectedEnd;
        }
        const value = (@as(u16, self.Data[self.Offset]) << 8) | self.Data[self.Offset + 1];
        self.Offset += 2;
        return value;
    }

    pub fn readI16(self: *Reader) ParseError!i16 {
        return @bitCast(try self.readU16());
    }

    pub fn readU32(self: *Reader) ParseError!u32 {
        if (self.remaining() < 4) {
            return ParseError.UnexpectedEnd;
        }
        const bytes = self.Data[self.Offset..][0..4];
        const value = (@as(u32, bytes[0]) << 24) | (@as(u32, bytes[1]) << 16) |
            (@as(u32, bytes[2]) << 8) | bytes[3];
        self.Offset += 4;
        return value;
    }

    pub fn slice(self: *const Reader, offset: usize, length: usize) ParseError![]const u8 {
        if (offset > self.Data.len or length > self.Data.len - offset) {
            return ParseError.TableOutOfBounds;
        }
        return self.Data[offset .. offset + length];
    }
};
