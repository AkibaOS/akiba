//! AFS read operations

const cache = @import("cache.zig");
const cluster = @import("cluster.zig");
const compare = @import("../../utils/string/compare.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs = @import("../../common/constants/fs.zig");
const int = @import("../../utils/types/int.zig");
const location = @import("location.zig");
const ptr = @import("../../utils/types/ptr.zig");
const types = @import("types.zig");

pub fn find_entry(afs: anytype, stack_cluster: u32, identity: []const u8) ?types.Entry {
    var current = stack_cluster;

    while (cluster.is_valid(current)) {
        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(cluster.to_lba(afs, current), &sector)) {
            return null;
        }

        const entry = ptr.of(types.Entry, @intFromPtr(&sector));

        if (entry.is_end()) return null;

        if (entry.is_unit() or entry.is_stack()) {
            if (compare.equals(entry.get_identity(), identity)) {
                if (entry.is_stack()) {
                    cache.store(afs, entry.first_cluster, stack_cluster);
                }
                return entry.*;
            }
        }

        current = cluster.get_next(afs, current) catch return null;
    }

    return null;
}

pub fn view_unit(afs: anytype, entry: types.Entry, buffer: []u8) !usize {
    var current = entry.first_cluster;
    var viewed: usize = 0;

    while (cluster.is_valid(current)) {
        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(cluster.to_lba(afs, current), &sector)) {
            return error.ReadFailed;
        }

        const to_copy = @min(fs.SECTOR_SIZE, entry.size - viewed);
        const end = @min(viewed + to_copy, buffer.len);
        copy.bytes(buffer[viewed..end], sector[0 .. end - viewed]);

        viewed += to_copy;
        if (viewed >= entry.size) break;

        current = try cluster.get_next(afs, current);
    }

    return viewed;
}

pub fn list_stack(afs: anytype, stack_cluster: u32, items: []types.StackItem) !usize {
    var current = stack_cluster;
    var count: usize = 0;

    while (cluster.is_valid(current)) {
        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(cluster.to_lba(afs, current), &sector)) {
            return error.ReadFailed;
        }

        const entry = ptr.of(types.Entry, @intFromPtr(&sector));

        if (entry.is_end()) return count;

        if (entry.is_unit() or entry.is_stack()) {
            if (count >= items.len) return count;

            copy.bytes(items[count].identity[0..entry.name_len], entry.get_identity());
            items[count].identity_len = entry.name_len;
            items[count].is_stack = entry.is_stack();

            copy.bytes(items[count].owner_name[0..entry.owner_name_len], entry.get_owner());
            items[count].owner_name_len = entry.owner_name_len;
            items[count].permission_type = entry.permission_type;
            items[count].modified_time = entry.modified_time;

            items[count].size = if (entry.is_stack())
                int.u32_of(calculate_stack_size(afs, entry.first_cluster) catch 0)
            else
                int.u32_of(entry.size);

            count += 1;
        }

        current = cluster.get_next(afs, current) catch return count;
    }

    return count;
}

pub fn calculate_stack_size(afs: anytype, stack_cluster: u32) !u64 {
    var current = stack_cluster;
    var total: u64 = 0;

    while (cluster.is_valid(current)) {
        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(cluster.to_lba(afs, current), &sector)) {
            return error.ReadFailed;
        }

        const entry = ptr.of(types.Entry, @intFromPtr(&sector));

        if (entry.is_end()) return total;

        if (entry.is_unit()) {
            total += entry.size;
        } else if (entry.is_stack()) {
            total += calculate_stack_size(afs, entry.first_cluster) catch 0;
        }

        current = cluster.get_next(afs, current) catch return total;
    }

    return total;
}

pub fn get_unit_size(afs: anytype, loc: []const u8) !u64 {
    if (loc.len == 0) return error.InvalidLocation;

    var current = afs.root_cluster;
    var start: usize = location.skip_root(loc);
    var i: usize = start;

    while (i <= loc.len) : (i += 1) {
        const is_end = (i == loc.len);
        const is_slash = !is_end and loc[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = loc[start..i];
                const entry = find_entry(afs, current, component) orelse return error.NotFound;

                if (is_end) {
                    if (!entry.is_unit()) return error.NotAUnit;
                    return entry.size;
                } else {
                    if (!entry.is_stack()) return error.NotAStack;
                    current = entry.first_cluster;
                }
            }
            start = i + 1;
        }
    }

    return error.InvalidLocation;
}

pub fn view_unit_at(afs: anytype, loc: []const u8, buffer: []u8) !usize {
    var current = afs.root_cluster;
    var start: usize = location.skip_root(loc);
    var i: usize = start;

    while (i <= loc.len) : (i += 1) {
        const is_end = (i == loc.len);
        const is_slash = !is_end and loc[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = loc[start..i];
                const entry = find_entry(afs, current, component) orelse return error.NotFound;

                if (is_end) {
                    if (!entry.is_unit()) return error.NotAUnit;
                    return view_unit(afs, entry, buffer);
                } else {
                    if (!entry.is_stack()) return error.NotAStack;
                    current = entry.first_cluster;
                }
            }
            start = i + 1;
        }
    }

    return error.InvalidLocation;
}
