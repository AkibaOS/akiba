//! Byte size formatting

const int = @import("int.zig");

pub fn format(bytes: u64, buf: []u8) []const u8 {
    const kb = bytes / 1024;
    const mb = kb / 1024;

    if (mb >= 1024) {
        // Round: add 512 (half of 1024) before dividing
        const gb_tenths = (mb * 10 + 512) / 1024;
        const gb_whole = gb_tenths / 10;
        const gb_frac = gb_tenths % 10;

        var pos: usize = 0;
        const whole_str = int.toStr(gb_whole, buf[pos..]);
        pos += whole_str.len;
        buf[pos] = '.';
        pos += 1;
        buf[pos] = '0' + @as(u8, @intCast(gb_frac));
        pos += 1;
        buf[pos] = ' ';
        pos += 1;
        buf[pos] = 'G';
        pos += 1;
        buf[pos] = 'B';
        pos += 1;
        return buf[0..pos];
    } else if (mb > 0) {
        const num_str = int.toStr(mb, buf);
        buf[num_str.len] = ' ';
        buf[num_str.len + 1] = 'M';
        buf[num_str.len + 2] = 'B';
        return buf[0 .. num_str.len + 3];
    } else if (kb > 0) {
        const num_str = int.toStr(kb, buf);
        buf[num_str.len] = ' ';
        buf[num_str.len + 1] = 'K';
        buf[num_str.len + 2] = 'B';
        return buf[0 .. num_str.len + 3];
    } else {
        const num_str = int.toStr(bytes, buf);
        buf[num_str.len] = ' ';
        buf[num_str.len + 1] = 'B';
        return buf[0 .. num_str.len + 2];
    }
}
