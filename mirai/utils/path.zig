//! Path utilities

const kata_mod = @import("../kata/kata.zig");

/// Resolve a path (relative or absolute) to full path
pub fn resolve_path(kata: *kata_mod.Kata, path: []const u8, buffer: []u8) []const u8 {
    if (path[0] == '/') {
        // Absolute path
        @memcpy(buffer[0..path.len], path);
        return buffer[0..path.len];
    }

    // Relative path
    const cwd = kata.current_location[0..kata.current_location_len];
    var len: usize = 0;

    @memcpy(buffer[0..cwd.len], cwd);
    len += cwd.len;

    if (cwd[cwd.len - 1] != '/') {
        buffer[len] = '/';
        len += 1;
    }

    @memcpy(buffer[len .. len + path.len], path);
    len += path.len;

    return buffer[0..len];
}

/// Check if a path points to a device file
pub fn is_device_path(path: []const u8) bool {
    return path.len > 16 and
        path[0] == '/' and path[1] == 's' and path[2] == 'y' and path[3] == 's' and
        path[4] == 't' and path[5] == 'e' and path[6] == 'm' and path[7] == '/' and
        path[8] == 'd' and path[9] == 'e' and path[10] == 'v' and path[11] == 'i' and
        path[12] == 'c' and path[13] == 'e' and path[14] == 's' and path[15] == '/';
}
