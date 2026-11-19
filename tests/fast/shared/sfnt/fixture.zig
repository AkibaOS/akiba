//! Independent SFNT Fixture Encoding

const constants = @import("tests").fast.constants.render;
const types = @import("tests").fast.types.render;

const SFNTFixture = types.SFNTFixture;
const TableFixture = types.TableFixture;

pub fn writeU16(bytes: []u8, offset: usize, value: u16) void {
    bytes[offset] = @truncate(value >> 8);
    bytes[offset + 1] = @truncate(value);
}

pub fn writeU32(bytes: []u8, offset: usize, value: u32) void {
    bytes[offset] = @truncate(value >> 24);
    bytes[offset + 1] = @truncate(value >> 16);
    bytes[offset + 2] = @truncate(value >> 8);
    bytes[offset + 3] = @truncate(value);
}

pub fn pack(tables: []const TableFixture) SFNTFixture {
    var result: SFNTFixture = .{ .Data = @splat(0), .Length = 12 + tables.len * 16 };
    writeU32(&result.Data, 0, constants.SFNT_VERSION);
    writeU16(&result.Data, 4, @intCast(tables.len));
    if (tables.len > 0) {
        var power: u16 = 1;
        var selector: u16 = 0;
        while (@as(usize, power) * 2 <= tables.len) : (selector += 1) power *= 2;
        writeU16(&result.Data, 6, power * 16);
        writeU16(&result.Data, 8, selector);
        writeU16(&result.Data, 10, @as(u16, @intCast(tables.len * 16)) - power * 16);
    }
    for (tables, 0..) |table, index| {
        const offset = result.Length;
        const padded = (table.Bytes.len + 3) & ~@as(usize, 3);
        @memcpy(result.Data[offset..][0..table.Bytes.len], table.Bytes);
        const record = 12 + index * 16;
        writeU32(&result.Data, record, table.Tag);
        writeU32(&result.Data, record + 4, checksum(result.Data[offset..][0..padded]));
        writeU32(&result.Data, record + 8, @intCast(offset));
        writeU32(&result.Data, record + 12, @intCast(table.Bytes.len));
        result.Length += padded;
    }
    return result;
}

fn checksum(bytes: []const u8) u32 {
    var sum: u32 = 0;
    var offset: usize = 0;
    while (offset < bytes.len) : (offset += 4) {
        sum +%= (@as(u32, bytes[offset]) << 24) | (@as(u32, bytes[offset + 1]) << 16) |
            (@as(u32, bytes[offset + 2]) << 8) | bytes[offset + 3];
    }
    return sum;
}
