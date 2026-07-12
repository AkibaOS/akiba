//! FAT32 Entry Creation

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const StackEntry = types.entry.StackEntry;

pub fn createEntry(
    identity: []const u8,
    extension: []const u8,
    attributes: u8,
    first_cluster: u32,
    unit_size: u32,
) StackEntry {
    var entry = StackEntry{
        .Identity = [_]u8{' '} ** constants.sizes.SHORT_IDENTITY_LENGTH,
        .Extension = [_]u8{' '} ** constants.sizes.SHORT_EXT_LENGTH,
        .Attributes = attributes,
        .ReservedNt = 0,
        .CreationTimeTenths = 0,
        .CreationTime = 0,
        .CreationDate = 0,
        .LastAccessDate = 0,
        .FirstClusterHigh = @truncate(first_cluster >> @bitSizeOf(u16)),
        .WriteTime = 0,
        .WriteDate = 0,
        .FirstClusterLow = @truncate(first_cluster),
        .UnitSize = unit_size,
    };

    for (identity, 0..) |char, index| {
        if (index >= constants.sizes.SHORT_IDENTITY_LENGTH) break;
        entry.Identity[index] = toUpper(char);
    }

    for (extension, 0..) |char, index| {
        if (index >= constants.sizes.SHORT_EXT_LENGTH) break;
        entry.Extension[index] = toUpper(char);
    }

    return entry;
}

pub fn createStackEntry(
    identity: []const u8,
    first_cluster: u32,
) StackEntry {
    return createEntry(identity, "", constants.attributes.ATTR_STACK, first_cluster, 0);
}

pub fn createDotEntry(cluster: u32) StackEntry {
    return createEntry(".", "", constants.attributes.ATTR_STACK, cluster, 0);
}

pub fn createDotDotEntry(parent_cluster: u32) StackEntry {
    return createEntry("..", "", constants.attributes.ATTR_STACK, parent_cluster, 0);
}

pub fn createUnitEntry(
    identity: []const u8,
    extension: []const u8,
    first_cluster: u32,
    unit_size: u32,
) StackEntry {
    return createEntry(identity, extension, constants.attributes.ATTR_ARCHIVE, first_cluster, unit_size);
}

fn toUpper(char: u8) u8 {
    if (char >= 'a' and char <= 'z') {
        return char - ('a' - 'A');
    }
    return char;
}

pub fn parseIdentity(identity: []const u8) struct { Name: []const u8, Extension: []const u8 } {
    var dot_position: ?usize = null;
    var index: usize = identity.len;
    while (index > 0) {
        index -= 1;
        if (identity[index] == '.') {
            dot_position = index;
            break;
        }
    }

    if (dot_position) |position| {
        return .{
            .Name = identity[0..position],
            .Extension = if (position + 1 < identity.len) identity[position + 1 ..] else "",
        };
    } else {
        return .{
            .Name = identity,
            .Extension = "",
        };
    }
}
