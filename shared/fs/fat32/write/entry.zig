//! FAT32 Entry Creation

const std = @import("std");
const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const StackEntry = types.StackEntry;

/// Create a short (8.3) entry
pub fn create_entry(
    identity: []const u8,
    extension: []const u8,
    attributes: u8,
    first_cluster: u32,
    unit_size: u32,
) StackEntry {
    var entry = StackEntry{
        .identity = .{ ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
        .extension = .{ ' ', ' ', ' ' },
        .attributes = attributes,
        .reserved_nt = 0,
        .creation_time_tenths = 0,
        .creation_time = 0,
        .creation_date = 0,
        .last_access_date = 0,
        .first_cluster_high = @intCast((first_cluster >> 16) & 0xFFFF),
        .write_time = 0,
        .write_date = 0,
        .first_cluster_low = @intCast(first_cluster & 0xFFFF),
        .unit_size = unit_size,
    };

    // Copy identity (uppercase)
    for (identity, 0..) |c, i| {
        if (i >= 8) break;
        entry.identity[i] = to_upper(c);
    }

    // Copy extension (uppercase)
    for (extension, 0..) |c, i| {
        if (i >= 3) break;
        entry.extension[i] = to_upper(c);
    }

    return entry;
}

/// Create a stack entry
pub fn create_stack_entry(
    identity: []const u8,
    first_cluster: u32,
) StackEntry {
    return create_entry(identity, "", constants.attr_stack, first_cluster, 0);
}

/// Create a "." entry for current stack
pub fn create_dot_entry(cluster: u32) StackEntry {
    return create_entry(".", "", constants.attr_stack, cluster, 0);
}

/// Create a ".." entry for parent stack
pub fn create_dotdot_entry(parent_cluster: u32) StackEntry {
    return create_entry("..", "", constants.attr_stack, parent_cluster, 0);
}

/// Create a unit entry
pub fn create_unit_entry(
    identity: []const u8,
    extension: []const u8,
    first_cluster: u32,
    unit_size: u32,
) StackEntry {
    return create_entry(identity, extension, constants.attr_archive, first_cluster, unit_size);
}

/// Convert character to uppercase
fn to_upper(c: u8) u8 {
    if (c >= 'a' and c <= 'z') {
        return c - 32;
    }
    return c;
}

/// Parse identity into name and extension parts
pub fn parse_identity(identity: []const u8) struct { name: []const u8, ext: []const u8 } {
    // Find last dot
    var dot_pos: ?usize = null;
    var i: usize = identity.len;
    while (i > 0) {
        i -= 1;
        if (identity[i] == '.') {
            dot_pos = i;
            break;
        }
    }

    if (dot_pos) |pos| {
        return .{
            .name = identity[0..pos],
            .ext = if (pos + 1 < identity.len) identity[pos + 1 ..] else "",
        };
    } else {
        return .{
            .name = identity,
            .ext = "",
        };
    }
}
