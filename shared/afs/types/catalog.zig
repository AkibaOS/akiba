//! AFS Catalog Types (Stack, Unit, Thread Records)

const constants = @import("shared").afs.constants;
const volume = @import("shared").afs.types.volume;

const ChannelInfo = volume.ChannelInfo;

pub const StackRecord = extern struct {
    RecordType: u16 = constants.records.INDEX_STACK,
    Flags: u16 = 0,
    Valence: u32 = 0,
    NodeId: u32 = 0,
    CreationTimestamp: u64 = 0,
    ModificationTimestamp: u64 = 0,
    AttributeModificationTimestamp: u64 = 0,
    AccessTimestamp: u64 = 0,
    BackupTimestamp: u64 = 0,
    Permissions: Permissions = .{},
    Special: SpecialInfo = .{ .Raw = [_]u8{0} ** 16 },
    TextEncoding: u32 = 0,
    Reserved: u32 = 0,

    pub fn isEmpty(self: *const StackRecord) bool {
        return self.Valence == 0;
    }
};

pub const UnitRecord = extern struct {
    RecordType: u16 = constants.records.INDEX_UNIT,
    Flags: u16 = 0,
    Reserved1: u32 = 0,
    NodeId: u32 = 0,
    CreationTimestamp: u64 = 0,
    ModificationTimestamp: u64 = 0,
    AttributeModificationTimestamp: u64 = 0,
    AccessTimestamp: u64 = 0,
    BackupTimestamp: u64 = 0,
    Permissions: Permissions = .{},
    Special: SpecialInfo = .{ .Raw = [_]u8{0} ** 16 },
    TextEncoding: u32 = 0,
    Reserved2: u32 = 0,
    DataChannel: ChannelInfo = .{},
    ResourceChannel: ChannelInfo = .{},

    pub fn hasResourceChannel(self: *const UnitRecord) bool {
        return (self.Flags & constants.flags.UNIT_HAS_RESOURCE_CHANNEL) != 0;
    }

    pub fn hasTwins(self: *const UnitRecord) bool {
        return (self.Flags & constants.flags.UNIT_HAS_TWINS) != 0;
    }
};

pub const ThreadRecord = extern struct {
    RecordType: u16 = constants.records.INDEX_STACK_THREAD,
    Reserved: u16 = 0,
    ParentNodeId: u32 = 0,
    IdentityLength: u16 = 0,
    Identity: [256]u16 = [_]u16{0} ** 256,

    pub fn getIdentity(self: *const ThreadRecord) []const u16 {
        return self.Identity[0..self.IdentityLength];
    }
};

pub const Permissions = extern struct {
    OwnerId: u32 = 0,
    GroupId: u32 = 0,
    AdminFlags: u8 = 0,
    OwnerFlags: u8 = 0,
    Mode: u16 = 0o755,
    Special: SpecialPermissions = .{ .InodeNumber = 0 },
};

pub const SpecialPermissions = extern union {
    InodeNumber: u32,
    LinkCount: u32,
    RawDevice: u32,
};

pub const SpecialInfo = extern union {
    Raw: [16]u8,
    AliasInfo: AliasInfo,
    TwinInfo: TwinInfo,
};

pub const AliasInfo = extern struct {
    TargetNodeId: u32 = 0,
    TargetParentNodeId: u32 = 0,
    Reserved: [8]u8 = [_]u8{0} ** 8,
};

pub const TwinInfo = extern struct {
    FirstTwinNodeId: u32 = 0,
    Reserved: [12]u8 = [_]u8{0} ** 12,
};
