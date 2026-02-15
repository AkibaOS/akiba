//! AFS write operations

const cluster = @import("cluster.zig");
const compare = @import("../../utils/string/compare.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs = @import("../../common/constants/fs.zig");
const int = @import("../../utils/types/int.zig");
const location = @import("location.zig");
const ptr = @import("../../utils/types/ptr.zig");
const read = @import("read.zig");
const types = @import("types.zig");

pub fn navigate_to_stack(afs: anytype, loc: []const u8) !u32 {
    var current = afs.root_cluster;
    var start: usize = location.skip_root(loc);
    var i: usize = start;

    while (i <= loc.len) : (i += 1) {
        const is_end = (i == loc.len);
        const is_slash = !is_end and loc[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = loc[start..i];
                const entry = read.find_entry(afs, current, component) orelse return error.NotFound;

                if (!entry.is_stack()) return error.NotAStack;
                current = entry.first_cluster;
            }
            start = i + 1;
        }
    }

    return current;
}

pub fn create_unit(afs: anytype, loc: []const u8) !void {
    const parent_loc = location.parent(loc);
    const ident = location.identity(loc);

    if (ident.len == 0 or ident.len > fs.MAX_IDENTITY_LEN) {
        return error.InvalidIdentity;
    }

    var parent_cluster = afs.root_cluster;
    if (parent_loc.len > 1) {
        parent_cluster = try navigate_to_stack(afs, parent_loc);
    }

    if (read.find_entry(afs, parent_cluster, ident)) |_| {
        return error.UnitExists;
    }

    const unit_cluster = try cluster.allocate(afs);

    var new_entry = types.Entry{
        .entry_type = fs.ENTRY_TYPE_UNIT,
        .name_len = int.u8_of(ident.len),
        .name = undefined,
        .owner_name_len = 0,
        .owner_name = undefined,
        .permission_type = fs.PERM_OWNER,
        .reserved = 0,
        .first_cluster = unit_cluster,
        .size = 0,
        .created_time = 0,
        .modified_time = 0,
    };

    copy.zero(&new_entry.name);
    copy.zero(&new_entry.owner_name);
    copy.bytes(new_entry.name[0..ident.len], ident);

    try add_stack_entry(afs, parent_cluster, new_entry);
}

pub fn mark_unit(afs: anytype, loc: []const u8, data: []const u8) !void {
    const parent_loc = location.parent(loc);
    const ident = location.identity(loc);

    var parent_cluster = afs.root_cluster;
    if (parent_loc.len > 1) {
        parent_cluster = try navigate_to_stack(afs, parent_loc);
    }

    const entry = read.find_entry(afs, parent_cluster, ident) orelse {
        try create_unit(afs, loc);
        const new_entry = read.find_entry(afs, parent_cluster, ident) orelse return error.CreateFailed;
        try mark_unit_data(afs, new_entry.first_cluster, data);
        try update_unit_size(afs, parent_cluster, ident, data.len);
        return;
    };

    try mark_unit_data(afs, entry.first_cluster, data);
    try update_unit_size(afs, parent_cluster, ident, data.len);
}

pub fn mark_unit_data(afs: anytype, start_cluster: u32, data: []const u8) !void {
    var remaining = data.len;
    var offset: usize = 0;
    var current = start_cluster;

    while (remaining > 0) {
        const chunk = @min(remaining, fs.SECTOR_SIZE);
        const lba = cluster.to_lba(afs, current);

        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        copy.zero(&sector);
        copy.bytes(sector[0..chunk], data[offset .. offset + chunk]);

        if (!afs.device.write_sector(lba, &sector)) {
            return error.WriteFailed;
        }

        remaining -= chunk;
        offset += chunk;

        if (remaining > 0) {
            const next = try cluster.allocate(afs);
            try cluster.write_alloc(afs, current, next);
            current = next;
        } else {
            try cluster.write_alloc(afs, current, fs.CLUSTER_END);
        }
    }
}

pub fn add_stack_entry(afs: anytype, stack_cluster: u32, entry: types.Entry) !void {
    var current = stack_cluster;

    while (cluster.is_valid(current)) {
        const lba = cluster.to_lba(afs, current);

        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(lba, &sector)) {
            return error.ReadFailed;
        }

        const existing = ptr.of(types.Entry, @intFromPtr(&sector));

        if (existing.is_end()) {
            const entry_bytes = @as([*]const u8, @ptrCast(&entry))[0..@sizeOf(types.Entry)];
            copy.bytes(sector[0..@sizeOf(types.Entry)], entry_bytes);

            if (!afs.device.write_sector(lba, &sector)) {
                return error.WriteFailed;
            }
            return;
        }

        current = cluster.get_next(afs, current) catch {
            const new_cluster = try cluster.allocate(afs);
            try cluster.write_alloc(afs, stack_cluster, new_cluster);

            copy.zero(&sector);
            const entry_bytes = @as([*]const u8, @ptrCast(&entry))[0..@sizeOf(types.Entry)];
            copy.bytes(sector[0..@sizeOf(types.Entry)], entry_bytes);

            if (!afs.device.write_sector(cluster.to_lba(afs, new_cluster), &sector)) {
                return error.WriteFailed;
            }
            return;
        };
    }

    return error.StackFull;
}

pub fn update_unit_size(afs: anytype, stack_cluster: u32, ident: []const u8, new_size: usize) !void {
    var current = stack_cluster;

    while (cluster.is_valid(current)) {
        const lba = cluster.to_lba(afs, current);

        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(lba, &sector)) {
            return error.ReadFailed;
        }

        const entry = ptr.of(types.Entry, @intFromPtr(&sector));

        if (entry.is_end()) return error.NotFound;

        if (compare.equals(entry.get_identity(), ident)) {
            entry.size = new_size;

            if (!afs.device.write_sector(lba, &sector)) {
                return error.WriteFailed;
            }
            return;
        }

        current = cluster.get_next(afs, current) catch return error.NotFound;
    }

    return error.NotFound;
}
