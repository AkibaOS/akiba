//! Hikari AFS Adapter

const shared_afs = @import("shared").afs;

pub const btree = @import("btree.zig");
pub const reader = @import("reader.zig");
pub const block_io = @import("block.zig");

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
pub const ThreadRecord = shared_afs.types.ThreadRecord;
pub const SpanKey = shared_afs.types.SpanKey;
pub const SpanRecord = shared_afs.types.SpanRecord;
pub const Permissions = shared_afs.Permissions;
pub const AliasInfo = shared_afs.types.catalog.AliasInfo;
pub const TwinInfo = shared_afs.types.catalog.TwinInfo;
pub const JournalInfoCell = shared_afs.types.JournalInfoCell;
pub const JournalHeader = shared_afs.types.JournalHeader;
pub const Timestamp = shared_afs.types.Timestamp;

pub const BTree = btree.BTree;
pub const BTreeError = btree.BTreeError;

pub const Reader = reader.Reader;
pub const ReadError = reader.ReadError;
