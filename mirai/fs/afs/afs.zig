//! Akiba File System Driver

const cache = @import("cache.zig");
const cluster_ops = @import("cluster.zig");
const compare = @import("../../utils/string/compare.zig");
const fs = @import("../../common/constants/fs.zig");
const info = @import("info.zig");
const ptr = @import("../../utils/types/ptr.zig");
const read = @import("read.zig");
const types = @import("types.zig");
const write = @import("write.zig");

pub const BootSector = types.BootSector;
pub const Entry = types.Entry;
pub const StackItem = types.StackItem;
pub const DiskInfo = types.DiskInfo;

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
        used_clusters: u32,
        parent_cache: [fs.PARENT_CACHE_SIZE]types.ParentCacheEntry,
        parent_cache_count: usize,

        const Self = @This();

        pub fn init(device: *BlockDeviceType, partition_offset: u64) !Self {
            var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
            if (!device.read_sector(partition_offset, &sector)) {
                return error.ReadFailed;
            }

            const boot = ptr.of(BootSector, @intFromPtr(&sector));

            if (!compare.equals_bytes(boot.signature[0..8], fs.AFS_SIGNATURE)) {
                return error.InvalidFilesystem;
            }

            if (boot.boot_signature != fs.AFS_BOOT_SIG) {
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
                .used_clusters = boot.used_clusters,
                .parent_cache = undefined,
                .parent_cache_count = 0,
            };
        }

        // Cluster operations

        pub fn cluster_to_lba(self: *Self, cluster: u32) u64 {
            return cluster_ops.to_lba(self, cluster);
        }

        pub fn increment_used(self: *Self) void {
            self.used_clusters += 1;
        }

        pub fn decrement_used(self: *Self) void {
            if (self.used_clusters > 0) {
                self.used_clusters -= 1;
            }
        }

        // Cache operations

        pub fn get_parent_cluster(self: *Self, cluster: u32) ?u32 {
            return cache.lookup(self, cluster);
        }

        // Read operations

        pub fn find_entry(self: *Self, stack_cluster: u32, identity: []const u8) ?Entry {
            return read.find_entry(self, stack_cluster, identity);
        }

        pub fn view_unit(self: *Self, entry: Entry, buffer: []u8) !usize {
            return read.view_unit(self, entry, buffer);
        }

        pub fn list_stack(self: *Self, stack_cluster: u32, items: []StackItem) !usize {
            return read.list_stack(self, stack_cluster, items);
        }

        pub fn get_unit_size(self: *Self, location: []const u8) !u64 {
            return read.get_unit_size(self, location);
        }

        pub fn view_unit_at(self: *Self, location: []const u8, buffer: []u8) !usize {
            return read.view_unit_at(self, location, buffer);
        }

        // Write operations

        pub fn create_unit(self: *Self, location: []const u8) !void {
            return write.create_unit(self, location);
        }

        pub fn mark_unit(self: *Self, location: []const u8, data: []const u8) !void {
            return write.mark_unit(self, location, data);
        }

        pub fn get_disk_info(self: *Self) DiskInfo {
            return info.get_disk_info(self);
        }
    };
}
