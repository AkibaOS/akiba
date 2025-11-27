const afs = @import("../fs/afs.zig");
const ata = @import("../drivers/ata.zig");

pub const PathError = error{
    NotFound,
    ReadFailed,
    InvalidPath,
};

pub const ResolvedPath = struct {
    cluster: u32,
    is_directory: bool,
};

pub fn resolve_path(fs: *afs.AFS, current_cluster: u32, path: []const u8) PathError!ResolvedPath {
    if (path.len == 0) {
        return ResolvedPath{
            .cluster = current_cluster,
            .is_directory = true,
        };
    }

    var start_cluster: u32 = undefined;
    var path_start: usize = 0;

    if (path[0] == '/') {
        start_cluster = fs.root_cluster;
        path_start = 1;

        if (path.len == 1) {
            return ResolvedPath{
                .cluster = start_cluster,
                .is_directory = true,
            };
        }
    } else {
        start_cluster = current_cluster;
        path_start = 0;
    }

    var cluster = start_cluster;
    var is_dir = true;
    var i = path_start;

    while (i < path.len) {
        const component_start = i;
        while (i < path.len and path[i] != '/') : (i += 1) {}

        const component = path[component_start..i];

        if (component.len == 0) {
            if (i < path.len) i += 1;
            continue;
        }

        const result = find_entry_in_cluster(fs, cluster, component) catch |err| {
            return err;
        };

        cluster = result.cluster;
        is_dir = result.is_directory;

        if (i < path.len) i += 1;
    }

    return ResolvedPath{
        .cluster = cluster,
        .is_directory = is_dir,
    };
}

const EntryResult = struct {
    cluster: u32,
    is_directory: bool,
};

fn find_entry_in_cluster(fs: *afs.AFS, cluster: u32, name: []const u8) PathError!EntryResult {
    const lba = fs.cluster_to_lba(cluster);
    var sector_buffer: [ata.SECTOR_SIZE]u8 = undefined;

    if (!fs.device.read_sector(lba, &sector_buffer)) {
        return PathError.ReadFailed;
    }

    var search_name: [11]u8 = [_]u8{' '} ** 11;

    var dot_pos: ?usize = null;
    for (name, 0..) |c, idx| {
        if (c == '.') {
            dot_pos = idx;
            break;
        }
    }

    if (dot_pos) |pos| {
        const name_len = @min(pos, 8);
        const ext_start = pos + 1;
        const ext_len = @min(name.len - ext_start, 3);

        for (name[0..name_len], 0..) |c, idx| {
            search_name[idx] = to_upper(c);
        }
        for (name[ext_start .. ext_start + ext_len], 0..) |c, idx| {
            search_name[8 + idx] = to_upper(c);
        }
    } else {
        const name_len = @min(name.len, 11);
        for (name[0..name_len], 0..) |c, idx| {
            search_name[idx] = to_upper(c);
        }
    }

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const entry_offset = i * 32;
        const entry = @as(*afs.DirectoryEntry, @ptrCast(@alignCast(&sector_buffer[entry_offset])));

        if (entry.name_0 == 0x00) break;
        if (entry.name_0 == 0xE5) continue;
        if (entry.attributes == 0x0F) continue;
        if ((entry.attributes & afs.ATTR_VOLUME_ID) != 0) continue;

        const entry_name = get_entry_name(entry);

        var match = true;
        for (search_name, 0..) |c, j| {
            if (entry_name[j] != c) {
                match = false;
                break;
            }
        }

        if (match) {
            const entry_cluster = (@as(u32, entry.first_cluster_high) << 16) | @as(u32, entry.first_cluster_low);
            const is_dir = (entry.attributes & afs.ATTR_DIRECTORY) != 0;

            return EntryResult{
                .cluster = entry_cluster,
                .is_directory = is_dir,
            };
        }
    }

    return PathError.NotFound;
}

pub fn get_parent_cluster(fs: *afs.AFS, cluster: u32) PathError!u32 {
    if (cluster == fs.root_cluster) return fs.root_cluster;

    const lba = fs.cluster_to_lba(cluster);
    var sector_buffer: [ata.SECTOR_SIZE]u8 = undefined;

    if (!fs.device.read_sector(lba, &sector_buffer)) {
        return PathError.ReadFailed;
    }

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const entry_offset = i * 32;
        const entry = @as(*afs.DirectoryEntry, @ptrCast(@alignCast(&sector_buffer[entry_offset])));

        if (entry.name_0 == 0x00) break;
        if (entry.name_0 == 0xE5) continue;

        const name = get_entry_name(entry);
        if (name[0] == '.' and name[1] == '.' and name[2] == ' ') {
            const parent = (@as(u32, entry.first_cluster_high) << 16) | @as(u32, entry.first_cluster_low);
            if (parent == 0) return fs.root_cluster;
            return parent;
        }
    }

    return fs.root_cluster;
}

fn get_entry_name(entry: *const afs.DirectoryEntry) [11]u8 {
    return [11]u8{
        entry.name_0, entry.name_1, entry.name_2,  entry.name_3,
        entry.name_4, entry.name_5, entry.name_6,  entry.name_7,
        entry.name_8, entry.name_9, entry.name_10,
    };
}

fn to_upper(c: u8) u8 {
    if (c >= 'a' and c <= 'z') {
        return c - 32;
    }
    return c;
}
