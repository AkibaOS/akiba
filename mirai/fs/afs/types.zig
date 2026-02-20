//! AFS type definitions

const fs = @import("../../common/constants/fs.zig");

pub const BootSector = extern struct {
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

pub const Entry = extern struct {
    entry_type: u8,
    name_len: u8,
    name: [fs.MAX_IDENTITY_LEN]u8,
    owner_name_len: u8,
    owner_name: [fs.MAX_OWNER_NAME_LEN]u8,
    permission_type: u8,
    reserved: u8,
    first_cluster: u32,
    size: u64,
    created_time: u64,
    modified_time: u64,

    pub fn get_identity(self: *const Entry) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn get_owner(self: *const Entry) []const u8 {
        return self.owner_name[0..self.owner_name_len];
    }

    pub fn is_unit(self: *const Entry) bool {
        return self.entry_type == fs.ENTRY_TYPE_UNIT;
    }

    pub fn is_stack(self: *const Entry) bool {
        return self.entry_type == fs.ENTRY_TYPE_STACK;
    }

    pub fn is_end(self: *const Entry) bool {
        return self.entry_type == fs.ENTRY_TYPE_END;
    }
};

pub const StackItem = struct {
    identity: [fs.MAX_LOCATION_LENGTH]u8,
    identity_len: usize,
    is_stack: bool,
    size: u32,
    modified_time: u64,
    owner_name: [fs.MAX_OWNER_NAME_LEN]u8,
    owner_name_len: usize,
    permission_type: u8,

    pub fn get_identity(self: *const StackItem) []const u8 {
        return self.identity[0..self.identity_len];
    }

    pub fn get_owner(self: *const StackItem) []const u8 {
        return self.owner_name[0..self.owner_name_len];
    }
};

pub const ParentCacheEntry = struct {
    cluster: u32,
    parent: u32,
};

pub const DiskInfo = struct {
    total_bytes: u64,
    used_bytes: u64,
};
