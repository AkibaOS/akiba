//! C-string utilities

pub fn len(str: [*:0]const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

pub fn toSlice(str: [*:0]const u8) []const u8 {
    return str[0..len(str)];
}

pub fn findNull(buf: []const u8) usize {
    var i: usize = 0;
    while (i < buf.len and buf[i] != 0) : (i += 1) {}
    return i;
}
