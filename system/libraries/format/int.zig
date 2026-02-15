//! Integer formatting

pub fn toStr(num: u64, buf: []u8) []u8 {
    if (num == 0) {
        buf[0] = '0';
        return buf[0..1];
    }

    var n = num;
    var i: usize = 0;

    while (n > 0) : (i += 1) {
        buf[i] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
    }

    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }

    return buf[0..i];
}
