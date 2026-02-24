//! AFS location utilities

pub fn parent(location: []const u8) []const u8 {
    var i: usize = location.len;
    while (i > 0) : (i -= 1) {
        if (location[i - 1] == '/') {
            if (i == 1) return "/";
            return location[0 .. i - 1];
        }
    }
    return "/";
}

pub fn identity(location: []const u8) []const u8 {
    var i: usize = location.len;
    while (i > 0) : (i -= 1) {
        if (location[i - 1] == '/') {
            return location[i..];
        }
    }
    return location;
}

pub fn is_absolute(location: []const u8) bool {
    return location.len > 0 and location[0] == '/';
}

pub fn skip_root(location: []const u8) usize {
    return if (is_absolute(location)) 1 else 0;
}
