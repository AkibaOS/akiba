//! Size formatting

const int = @import("int.zig");

const KB: u64 = 1024;
const MB: u64 = 1024 * 1024;
const GB: u64 = 1024 * 1024 * 1024;

pub fn format(bytes: u64, buf: []u8) []u8 {
    if (bytes < KB) {
        const s = int.toStr(bytes, buf);
        buf[s.len] = 'B';
        return buf[0 .. s.len + 1];
    } else if (bytes < MB) {
        const kb = bytes / KB;
        const s = int.toStr(kb, buf);
        buf[s.len] = 'K';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    } else if (bytes < GB) {
        const mb = bytes / MB;
        const s = int.toStr(mb, buf);
        buf[s.len] = 'M';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    } else {
        const gb = bytes / GB;
        const s = int.toStr(gb, buf);
        buf[s.len] = 'G';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    }
}
