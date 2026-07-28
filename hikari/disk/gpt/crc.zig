//! Hikari CRC32

const constants = @import("hikari").disk.constants;

const CRC32_TABLE = generateTable();

fn generateTable() [constants.crc.TABLE_SIZE]u32 {
    @setEvalBranchQuota(10000);
    var table: [constants.crc.TABLE_SIZE]u32 = undefined;
    var index: u32 = 0;
    while (index < constants.crc.TABLE_SIZE) : (index += 1) {
        var value: u32 = index;
        var bit: u32 = 0;
        while (bit < @bitSizeOf(u8)) : (bit += 1) {
            if ((value & 1) != 0) {
                value = (value >> 1) ^ constants.crc.POLYNOMIAL;
            } else {
                value = value >> 1;
            }
        }
        table[index] = value;
    }
    return table;
}

pub fn calculateCRC32(data: []const u8) u32 {
    var value: u32 = constants.crc.INITIAL;
    for (data) |byte| {
        const table_index: u8 = @truncate(value ^ byte);
        value = (value >> @bitSizeOf(u8)) ^ CRC32_TABLE[table_index];
    }
    return value ^ constants.crc.INITIAL;
}
