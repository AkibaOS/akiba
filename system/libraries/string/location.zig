//! Location utilities

pub fn getStackName(location: []const u8) []const u8 {
    if (location.len == 0 or (location.len == 1 and location[0] == '/')) {
        return "/";
    }

    var last_slash: usize = 0;
    for (location, 0..) |c, i| {
        if (c == '/') {
            last_slash = i;
        }
    }

    if (last_slash == location.len - 1 and location.len > 1) {
        var i: usize = location.len - 2;
        while (i > 0) : (i -= 1) {
            if (location[i] == '/') {
                return location[i + 1 .. location.len - 1];
            }
        }
        return location[1 .. location.len - 1];
    }

    if (last_slash + 1 < location.len) {
        return location[last_slash + 1 ..];
    }

    return location;
}

pub fn parent(location: []const u8, buf: []u8) []const u8 {
    if (location.len <= 1) {
        buf[0] = '/';
        return buf[0..1];
    }

    var end = location.len;
    if (location[end - 1] == '/') {
        end -= 1;
    }

    var i: usize = end;
    while (i > 0) : (i -= 1) {
        if (location[i - 1] == '/') {
            if (i == 1) {
                buf[0] = '/';
                return buf[0..1];
            }
            for (location[0 .. i - 1], 0..) |c, j| {
                buf[j] = c;
            }
            return buf[0 .. i - 1];
        }
    }

    buf[0] = '/';
    return buf[0..1];
}
