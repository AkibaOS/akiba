//! AFS Types

pub const volume = @import("volume.zig");
pub const btree = @import("btree.zig");
pub const catalog = @import("catalog.zig");
pub const extents = @import("extents.zig");
pub const attributes = @import("attributes.zig");
pub const journal = @import("journal.zig");
pub const timestamp = @import("timestamp.zig");

// Volume types
pub const VolumeHeader = volume.VolumeHeader;
pub const SpanDescriptor = volume.SpanDescriptor;
pub const ChannelInfo = volume.ChannelInfo;

// B-tree types
pub const BTreeNodeDescriptor = btree.NodeDescriptor;
pub const BTreeHeaderRecord = btree.HeaderRecord;
pub const IndexKey = btree.IndexKey;

// Catalog types
pub const StackRecord = catalog.StackRecord;
pub const UnitRecord = catalog.UnitRecord;
pub const ThreadRecord = catalog.ThreadRecord;
pub const Permissions = catalog.Permissions;
pub const SpecialPermissions = catalog.SpecialPermissions;
pub const SpecialInfo = catalog.SpecialInfo;
pub const AliasInfo = catalog.AliasInfo;
pub const TwinInfo = catalog.TwinInfo;

// Extent types
pub const SpanKey = extents.SpanKey;
pub const SpanRecord = extents.SpanRecord;

// Attribute types
pub const AttributeKey = attributes.AttributeKey;
pub const AttributeInlineRecord = attributes.AttributeInlineRecord;
pub const AttributeChannelRecord = attributes.AttributeChannelRecord;

// Journal types
pub const JournalInfoCell = journal.JournalInfoCell;
pub const JournalHeader = journal.JournalHeader;
pub const JournalCellList = journal.JournalCellList;
pub const JournalCellInfo = journal.JournalCellInfo;

// Timestamp
pub const Timestamp = timestamp.Timestamp;
