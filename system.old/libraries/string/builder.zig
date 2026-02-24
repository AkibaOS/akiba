//! String building

pub fn build(buf: []u8, parts: anytype) []const u8 {
    var pos: usize = 0;
    inline for (parts) |part| {
        for (part) |c| {
            if (pos >= buf.len) break;
            buf[pos] = c;
            pos += 1;
        }
    }
    return buf[0..pos];
}

pub fn concat(buf: []u8, a: []const u8, b: []const u8) []const u8 {
    var pos: usize = 0;
    for (a) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }
    for (b) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }
    return buf[0..pos];
}

pub fn concat3(buf: []u8, a: []const u8, b: []const u8, c: []const u8) []const u8 {
    var pos: usize = 0;
    for (a) |ch| {
        if (pos >= buf.len) break;
        buf[pos] = ch;
        pos += 1;
    }
    for (b) |ch| {
        if (pos >= buf.len) break;
        buf[pos] = ch;
        pos += 1;
    }
    for (c) |ch| {
        if (pos >= buf.len) break;
        buf[pos] = ch;
        pos += 1;
    }
    return buf[0..pos];
}
