//! Path utilities

const kata_mod = @import("../../kata/kata.zig");
const compare = @import("../string/compare.zig");

const DEVICE_PREFIX = "/system/devices/";

pub fn resolve(kata: *kata_mod.Kata, path: []const u8, buffer: []u8) []const u8 {
    if (path.len > 0 and path[0] == '/') {
        @memcpy(buffer[0..path.len], path);
        return buffer[0..path.len];
    }

    const cwd = kata.current_location[0..kata.current_location_len];
    var len: usize = cwd.len;

    @memcpy(buffer[0..cwd.len], cwd);

    if (cwd[cwd.len - 1] != '/') {
        buffer[len] = '/';
        len += 1;
    }

    @memcpy(buffer[len .. len + path.len], path);
    len += path.len;

    return buffer[0..len];
}

pub fn is_device(path: []const u8) bool {
    return compare.starts_with(path, DEVICE_PREFIX);
}

pub fn device_name(path: []const u8) []const u8 {
    return path[DEVICE_PREFIX.len..];
}
