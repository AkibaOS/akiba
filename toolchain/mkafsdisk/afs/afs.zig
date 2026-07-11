//! mkafsdisk AFS Adapter

const shared_afs = @import("shared").afs;

pub const writer = @import("writer.zig");

pub const constants = shared_afs.constants;
pub const types = shared_afs.types;

pub const VolumeHeader = shared_afs.VolumeHeader;
pub const SpanDescriptor = shared_afs.SpanDescriptor;
pub const ChannelInfo = shared_afs.ChannelInfo;
pub const BTreeNodeDescriptor = shared_afs.BTreeNodeDescriptor;
pub const BTreeHeaderRecord = shared_afs.BTreeHeaderRecord;
pub const IndexKey = shared_afs.IndexKey;
pub const StackRecord = shared_afs.StackRecord;
pub const UnitRecord = shared_afs.UnitRecord;
pub const Permissions = shared_afs.Permissions;
pub const JournalInfoCell = shared_afs.types.JournalInfoCell;
pub const JournalHeader = shared_afs.types.JournalHeader;

pub const Writer = writer.Writer;
