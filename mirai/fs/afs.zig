//! Akiba File System Driver
//! Case-sensitive, LFN-only filesystem

const serial = @import("../drivers/serial.zig");
const std = @import("std");

const SECTOR_SIZE = 512;

pub const AFSBootSector = extern struct {
    signature: [8]u8,
    version: u32,
    bytes_per_sector: u32,
    sectors_per_cluster: u32,
    total_clusters: u32,
    root_cluster: u32,
    alloc_table_sector: u32,
    alloc_table_size: u32,
    data_area_sector: u32,
    reserved: [466]u8,
    boot_signature: u16,
};

pub const AFSDirEntry = extern struct {
    entry_type: u8,
    name_len: u8,
    name: [255]u8,
    attributes: u8,
    reserved: u16,
    first_cluster: u32,
    file_size: u64,
    created_time: u64,
    modified_time: u64,
};

pub const ENTRY_TYPE_END: u8 = 0x00;
pub const ENTRY_TYPE_FILE: u8 = 0x01;
pub const ENTRY_TYPE_DIR: u8 = 0x02;

pub const ATTR_DIRECTORY: u8 = 0x10;

pub const ListEntry = struct {
    name: [256]u8,
    name_len: usize,
    is_directory: bool,
    file_size: u32,
};

pub fn AFS(comptime BlockDeviceType: type) type {
    return struct {
        device: *BlockDeviceType,
        partition_offset: u64,
        bytes_per_sector: u32,
        sectors_per_cluster: u32,
        total_clusters: u32,
        root_cluster: u32,
        alloc_table_sector: u32,
        alloc_table_size: u32,
        data_area_sector: u32,
        parent_cache: [256]ParentEntry,
        parent_cache_count: usize,

        const Self = @This();

        const ParentEntry = struct {
            cluster: u32,
            parent: u32,
        };

        pub fn init(device: *BlockDeviceType, partition_offset: u64) !Self {
            var boot_sector: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!device.read_sector(partition_offset, &boot_sector)) {
                return error.ReadFailed;
            }

            const boot = @as(*AFSBootSector, @ptrCast(@alignCast(&boot_sector)));

            if (!std.mem.eql(u8, boot.signature[0..8], "AKIBAFS!")) {
                return error.InvalidFilesystem;
            }

            if (boot.boot_signature != 0xAA55) {
                return error.InvalidFilesystem;
            }

            return Self{
                .device = device,
                .partition_offset = partition_offset,
                .bytes_per_sector = boot.bytes_per_sector,
                .sectors_per_cluster = boot.sectors_per_cluster,
                .total_clusters = boot.total_clusters,
                .root_cluster = boot.root_cluster,
                .alloc_table_sector = boot.alloc_table_sector,
                .alloc_table_size = boot.alloc_table_size,
                .data_area_sector = boot.data_area_sector,
                .parent_cache = undefined,
                .parent_cache_count = 0,
            };
        }

        pub fn find_file(self: *Self, dir_cluster: u32, filename: []const u8) ?AFSDirEntry {
            var cluster = dir_cluster;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return null;
                }

                const entry = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (entry.entry_type == ENTRY_TYPE_END) {
                    return null;
                }

                if (entry.entry_type == ENTRY_TYPE_FILE or entry.entry_type == ENTRY_TYPE_DIR) {
                    const entry_name = entry.name[0..entry.name_len];

                    if (std.mem.eql(u8, entry_name, filename)) {
                        if (entry.entry_type == ENTRY_TYPE_DIR) {
                            self.cache_parent(entry.first_cluster, dir_cluster);
                        }
                        return entry.*;
                    }
                }

                cluster = self.get_next_cluster(cluster) catch return null;
            }

            return null;
        }

        fn cache_parent(self: *Self, child: u32, parent: u32) void {
            for (self.parent_cache[0..self.parent_cache_count]) |*e| {
                if (e.cluster == child) {
                    e.parent = parent;
                    return;
                }
            }

            if (self.parent_cache_count < self.parent_cache.len) {
                self.parent_cache[self.parent_cache_count] = .{
                    .cluster = child,
                    .parent = parent,
                };
                self.parent_cache_count += 1;
            }
        }

        pub fn read_file(self: *Self, entry: AFSDirEntry, buffer: []u8) !usize {
            var cluster = entry.first_cluster;
            var bytes_read: usize = 0;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const bytes_to_copy = @min(SECTOR_SIZE, entry.file_size - bytes_read);
                for (sector_buf[0..bytes_to_copy], 0..) |byte, i| {
                    if (bytes_read + i >= buffer.len) break;
                    buffer[bytes_read + i] = byte;
                }

                bytes_read += bytes_to_copy;
                if (bytes_read >= entry.file_size) break;

                cluster = try self.get_next_cluster(cluster);
            }

            return bytes_read;
        }

        fn get_next_cluster(self: *Self, cluster: u32) !u32 {
            const table_entry_offset = cluster * 4;
            const table_sector = self.partition_offset + self.alloc_table_sector + (table_entry_offset / self.bytes_per_sector);
            const entry_offset = table_entry_offset % self.bytes_per_sector;

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!self.device.read_sector(table_sector, &sector_buf)) {
                return error.ReadFailed;
            }

            const next_cluster = @as(u32, sector_buf[entry_offset]) |
                (@as(u32, sector_buf[entry_offset + 1]) << 8) |
                (@as(u32, sector_buf[entry_offset + 2]) << 16) |
                (@as(u32, sector_buf[entry_offset + 3]) << 24);

            return next_cluster;
        }

        pub fn cluster_to_lba(self: *Self, cluster: u32) u64 {
            return self.partition_offset + self.data_area_sector + (cluster - 2);
        }

        pub fn list_directory(self: *Self, cluster_arg: u32, entries: []ListEntry) !usize {
            var cluster = cluster_arg;
            var count: usize = 0;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.cluster_to_lba(cluster);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const entry = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (entry.entry_type == ENTRY_TYPE_END) {
                    return count;
                }

                if (entry.entry_type == ENTRY_TYPE_FILE or entry.entry_type == ENTRY_TYPE_DIR) {
                    if (count >= entries.len) return count;

                    for (entry.name[0..entry.name_len], 0..) |c, i| {
                        entries[count].name[i] = c;
                    }
                    entries[count].name_len = entry.name_len;
                    entries[count].is_directory = (entry.entry_type == ENTRY_TYPE_DIR);
                    entries[count].file_size = @truncate(entry.file_size);
                    count += 1;
                }

                cluster = self.get_next_cluster(cluster) catch return count;
            }

            return count;
        }

        pub fn read_file_by_path(self: *Self, path: []const u8, buffer: []u8) !usize {
            var cluster = self.root_cluster;
            var start: usize = 0;
            var i: usize = 0;

            if (path.len > 0 and path[0] == '/') {
                start = 1;
                i = 1;
            }

            while (i <= path.len) : (i += 1) {
                const is_end = (i == path.len);
                const is_slash = !is_end and path[i] == '/';

                if (is_slash or is_end) {
                    if (i > start) {
                        const component = path[start..i];

                        const entry = self.find_file(cluster, component) orelse {
                            return error.NotFound;
                        };

                        if (is_end) {
                            if (entry.entry_type != ENTRY_TYPE_FILE) {
                                return error.NotAFile;
                            }
                            return self.read_file(entry, buffer);
                        } else {
                            if (entry.entry_type != ENTRY_TYPE_DIR) {
                                return error.NotADirectory;
                            }
                            cluster = entry.first_cluster;
                        }
                    }
                    start = i + 1;
                }
            }

            return error.InvalidPath;
        }

        pub fn get_parent_cluster(self: *Self, cluster: u32) ?u32 {
            if (cluster == self.root_cluster) return self.root_cluster;

            for (self.parent_cache[0..self.parent_cache_count]) |entry| {
                if (entry.cluster == cluster) {
                    return entry.parent;
                }
            }

            return null;
        }

        // Create a new empty file
        pub fn create_file(self: *Self, path: []const u8) !void {
            const parent_path = get_parent_path(path);
            const filename = get_filename(path);

            if (filename.len == 0 or filename.len > 255) {
                return error.InvalidFilename;
            }

            // Navigate to parent directory
            var parent_cluster = self.root_cluster;
            if (parent_path.len > 1) {
                parent_cluster = try self.navigate_to_directory(parent_path);
            }

            // Check if file already exists
            if (self.find_file(parent_cluster, filename)) |_| {
                return error.FileExists;
            }

            // Allocate cluster for new file
            const file_cluster = try self.allocate_cluster();

            // Create directory entry
            var new_entry = AFSDirEntry{
                .entry_type = ENTRY_TYPE_FILE,
                .name_len = @truncate(filename.len),
                .name = undefined,
                .attributes = 0,
                .reserved = 0,
                .first_cluster = file_cluster,
                .file_size = 0,
                .created_time = 0,
                .modified_time = 0,
            };

            @memset(&new_entry.name, 0);
            @memcpy(new_entry.name[0..filename.len], filename);

            // Add entry to parent directory
            try self.add_directory_entry(parent_cluster, new_entry);
        }

        // Write data to a file
        pub fn write_file(self: *Self, path: []const u8, data: []const u8) !void {
            const parent_path = get_parent_path(path);
            const filename = get_filename(path);

            // Navigate to parent directory
            var parent_cluster = self.root_cluster;
            if (parent_path.len > 1) {
                parent_cluster = try self.navigate_to_directory(parent_path);
            }

            // Find existing file
            const entry = self.find_file(parent_cluster, filename) orelse {
                // File doesn't exist, create it first
                try self.create_file(path);
                // Now find it
                const new_entry = self.find_file(parent_cluster, filename) orelse return error.CreateFailed;
                try self.write_file_data(new_entry.first_cluster, data);
                try self.update_file_size(parent_cluster, filename, data.len);
                return;
            };

            // Overwrite existing file
            try self.write_file_data(entry.first_cluster, data);
            try self.update_file_size(parent_cluster, filename, data.len);
        }

        // Helper: Navigate to directory by path
        fn navigate_to_directory(self: *Self, path: []const u8) !u32 {
            var cluster = self.root_cluster;
            var start: usize = if (path.len > 0 and path[0] == '/') 1 else 0;
            var i: usize = start;

            while (i <= path.len) : (i += 1) {
                const is_end = (i == path.len);
                const is_slash = !is_end and path[i] == '/';

                if (is_slash or is_end) {
                    if (i > start) {
                        const component = path[start..i];
                        const entry = self.find_file(cluster, component) orelse return error.NotFound;

                        if (entry.entry_type != ENTRY_TYPE_DIR) {
                            return error.NotADirectory;
                        }

                        cluster = entry.first_cluster;
                    }
                    start = i + 1;
                }
            }

            return cluster;
        }

        // Helper: Write data to file clusters
        fn write_file_data(self: *Self, start_cluster: u32, data: []const u8) !void {
            var remaining = data.len;
            var offset: usize = 0;
            var current_cluster = start_cluster;

            while (remaining > 0) {
                const chunk_size = @min(remaining, SECTOR_SIZE);
                const cluster_lba = self.partition_offset + self.data_area_sector + (current_cluster - 2);

                var buffer: [SECTOR_SIZE]u8 align(16) = undefined;
                @memset(&buffer, 0);
                @memcpy(buffer[0..chunk_size], data[offset .. offset + chunk_size]);

                if (!self.device.write_sector(cluster_lba, &buffer)) {
                    return error.WriteFailed;
                }

                remaining -= chunk_size;
                offset += chunk_size;

                if (remaining > 0) {
                    // Need another cluster
                    const next = try self.allocate_cluster();
                    try self.write_alloc_entry(current_cluster, next);
                    current_cluster = next;
                } else {
                    // Mark end of file
                    try self.write_alloc_entry(current_cluster, 0xFFFFFFFF);
                }
            }
        }

        // Helper: Allocate a new cluster
        fn allocate_cluster(self: *Self) !u32 {
            var cluster: u32 = 2; // Start from cluster 2

            while (cluster < self.total_clusters) : (cluster += 1) {
                const table_entry_offset = cluster * 4;
                const table_sector = self.partition_offset + self.alloc_table_sector + (table_entry_offset / self.bytes_per_sector);
                const entry_offset = table_entry_offset % self.bytes_per_sector;

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(table_sector, &sector_buf)) {
                    return error.ReadFailed;
                }

                const entry_value = @as(u32, sector_buf[entry_offset]) |
                    (@as(u32, sector_buf[entry_offset + 1]) << 8) |
                    (@as(u32, sector_buf[entry_offset + 2]) << 16) |
                    (@as(u32, sector_buf[entry_offset + 3]) << 24);

                if (entry_value == 0) {
                    // Free cluster found - mark as end of chain
                    try self.write_alloc_entry(cluster, 0xFFFFFFFF);
                    return cluster;
                }
            }

            return error.DiskFull;
        }

        // Helper: Write allocation table entry
        fn write_alloc_entry(self: *Self, cluster: u32, value: u32) !void {
            const table_entry_offset = cluster * 4;
            const table_sector = self.partition_offset + self.alloc_table_sector + (table_entry_offset / self.bytes_per_sector);
            const entry_offset = table_entry_offset % self.bytes_per_sector;

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!self.device.read_sector(table_sector, &sector_buf)) {
                return error.ReadFailed;
            }

            sector_buf[entry_offset] = @truncate(value & 0xFF);
            sector_buf[entry_offset + 1] = @truncate((value >> 8) & 0xFF);
            sector_buf[entry_offset + 2] = @truncate((value >> 16) & 0xFF);
            sector_buf[entry_offset + 3] = @truncate((value >> 24) & 0xFF);

            if (!self.device.write_sector(table_sector, &sector_buf)) {
                return error.WriteFailed;
            }
        }

        // Helper: Add directory entry
        fn add_directory_entry(self: *Self, dir_cluster: u32, entry: AFSDirEntry) !void {
            var cluster = dir_cluster;

            // Find free slot in directory
            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const existing = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (existing.entry_type == ENTRY_TYPE_END) {
                    // Found end marker - write new entry here
                    @memcpy(sector_buf[0..@sizeOf(AFSDirEntry)], std.mem.asBytes(&entry));

                    if (!self.device.write_sector(cluster_lba, &sector_buf)) {
                        return error.WriteFailed;
                    }
                    return;
                }

                cluster = self.get_next_cluster(cluster) catch {
                    // Need to allocate new cluster for directory
                    const new_cluster = try self.allocate_cluster();
                    try self.write_alloc_entry(dir_cluster, new_cluster);

                    // Write entry to new cluster
                    @memset(&sector_buf, 0);
                    @memcpy(sector_buf[0..@sizeOf(AFSDirEntry)], std.mem.asBytes(&entry));

                    const new_lba = self.partition_offset + self.data_area_sector + (new_cluster - 2);
                    if (!self.device.write_sector(new_lba, &sector_buf)) {
                        return error.WriteFailed;
                    }
                    return;
                };
            }

            return error.DirectoryFull;
        }

        // Helper: Update file size in directory entry
        fn update_file_size(self: *Self, dir_cluster: u32, filename: []const u8, new_size: usize) !void {
            var cluster = dir_cluster;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const entry = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (entry.entry_type == ENTRY_TYPE_END) {
                    return error.NotFound;
                }

                const entry_name = entry.name[0..entry.name_len];
                if (std.mem.eql(u8, entry_name, filename)) {
                    // Found it - update size
                    entry.file_size = new_size;

                    if (!self.device.write_sector(cluster_lba, &sector_buf)) {
                        return error.WriteFailed;
                    }
                    return;
                }

                cluster = self.get_next_cluster(cluster) catch return error.NotFound;
            }

            return error.NotFound;
        }

        // Helper: Get parent path
        fn get_parent_path(path: []const u8) []const u8 {
            var i: usize = path.len;
            while (i > 0) : (i -= 1) {
                if (path[i - 1] == '/') {
                    if (i == 1) return "/";
                    return path[0 .. i - 1];
                }
            }
            return "/";
        }

        // Helper: Get filename from path
        fn get_filename(path: []const u8) []const u8 {
            var i: usize = path.len;
            while (i > 0) : (i -= 1) {
                if (path[i - 1] == '/') {
                    return path[i..];
                }
            }
            return path;
        }
    };
}
