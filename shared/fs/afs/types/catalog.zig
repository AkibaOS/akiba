//! AFS Catalog Types (Stack, Unit, Thread Records)

const constants = @import("../constants/constants.zig");
const volume = @import("volume.zig");

const SpanDescriptor = volume.SpanDescriptor;
const ChannelInfo = volume.ChannelInfo;

pub const StackRecord = extern struct {
    record_type: u16 = constants.records.index_stack,
    flags: u16 = 0,
    valence: u32 = 0,
    node_id: u32 = 0,
    creation_timestamp: u64 = 0,
    modification_timestamp: u64 = 0,
    attribute_modification_timestamp: u64 = 0,
    access_timestamp: u64 = 0,
    backup_timestamp: u64 = 0,
    permissions: Permissions = .{},
    special: SpecialInfo = .{},
    text_encoding: u32 = 0,
    reserved: u32 = 0,

    pub fn is_empty(self: *const StackRecord) bool {
        return self.valence == 0;
    }
};

pub const UnitRecord = extern struct {
    record_type: u16 = constants.records.index_unit,
    flags: u16 = 0,
    reserved1: u32 = 0,
    node_id: u32 = 0,
    creation_timestamp: u64 = 0,
    modification_timestamp: u64 = 0,
    attribute_modification_timestamp: u64 = 0,
    access_timestamp: u64 = 0,
    backup_timestamp: u64 = 0,
    permissions: Permissions = .{},
    special: SpecialInfo = .{},
    text_encoding: u32 = 0,
    reserved2: u32 = 0,
    data_channel: ChannelInfo = .{},
    resource_channel: ChannelInfo = .{},

    pub fn has_resource_channel(self: *const UnitRecord) bool {
        return (self.flags & constants.flags.unit_has_resource_channel) != 0;
    }

    pub fn has_twins(self: *const UnitRecord) bool {
        return (self.flags & constants.flags.unit_has_twins) != 0;
    }
};

pub const ThreadRecord = extern struct {
    record_type: u16 = constants.records.index_stack_thread,
    reserved: u16 = 0,
    parent_node_id: u32 = 0,
    identity_length: u16 = 0,
    identity: [256]u16 = [_]u16{0} ** 256,

    pub fn get_identity(self: *const ThreadRecord) []const u16 {
        return self.identity[0..self.identity_length];
    }
};

pub const Permissions = extern struct {
    owner_id: u32 = 0,
    group_id: u32 = 0,
    admin_flags: u8 = 0,
    owner_flags: u8 = 0,
    mode: u16 = 0o755,
    special: SpecialPermissions = .{ .inode_number = 0 },
};

pub const SpecialPermissions = extern union {
    inode_number: u32,
    link_count: u32,
    raw_device: u32,
};

pub const SpecialInfo = extern union {
    raw: [16]u8,
    alias_info: AliasInfo,
    twin_info: TwinInfo,
};

pub const AliasInfo = extern struct {
    target_node_id: u32 = 0,
    target_parent_node_id: u32 = 0,
    reserved: [8]u8 = [_]u8{0} ** 8,
};

pub const TwinInfo = extern struct {
    first_twin_node_id: u32 = 0,
    reserved: [12]u8 = [_]u8{0} ** 12,
};
