//! AFS Volume Types

const constants = @import("shared").afs.constants;

pub const VolumeHeader = extern struct {
    Signature: u64 = constants.magic.SIGNATURE,
    Version: u16 = constants.magic.VERSION,
    Attributes: u32 = 0,
    LastBindTimestamp: u64 = 0,
    LastCheckTimestamp: u64 = 0,
    CreationTimestamp: u64 = 0,
    ModificationTimestamp: u64 = 0,
    BackupTimestamp: u64 = 0,
    CheckedTimestamp: u64 = 0,
    UnitCount: u32 = 0,
    StackCount: u32 = 0,
    CellSize: u32 = constants.sizes.DEFAULT_CELL_SIZE,
    TotalCells: u32 = 0,
    FreeCells: u32 = 0,
    NextNodeId: u32 = constants.nodes.FIRST_USER,
    WriteCount: u32 = 1,
    EncodingBitmap: u64 = 0,
    AllocationMapSize: u32 = 0,
    AllocationMapClump: u32 = 0,
    IndexNodeSize: u32 = constants.sizes.DEFAULT_CELL_SIZE,
    IndexTotalNodes: u32 = 0,
    IndexFreeNodes: u32 = 0,
    IndexClumpSize: u32 = 0,
    IndexRootNode: u32 = 1,
    IndexFirstLeaf: u32 = 1,
    IndexLastLeaf: u32 = 1,
    IndexDepth: u16 = 1,
    IndexRecordCount: u32 = 0,
    SpanOverflowNodeSize: u32 = constants.sizes.DEFAULT_CELL_SIZE,
    SpanOverflowTotalNodes: u32 = 0,
    SpanOverflowFreeNodes: u32 = 0,
    SpanOverflowClumpSize: u32 = 0,
    SpanOverflowRootNode: u32 = 0,
    SpanOverflowFirstLeaf: u32 = 0,
    SpanOverflowLastLeaf: u32 = 0,
    SpanOverflowDepth: u16 = 0,
    SpanOverflowRecordCount: u32 = 0,
    AttributesNodeSize: u32 = constants.sizes.DEFAULT_CELL_SIZE,
    AttributesTotalNodes: u32 = 0,
    AttributesFreeNodes: u32 = 0,
    AttributesClumpSize: u32 = 0,
    AttributesRootNode: u32 = 0,
    AttributesFirstLeaf: u32 = 0,
    AttributesLastLeaf: u32 = 0,
    AttributesDepth: u16 = 0,
    AttributesRecordCount: u32 = 0,
    AllocationMapSpan: SpanDescriptor = .{},
    IndexSpan: SpanDescriptor = .{},
    SpanOverflowSpan: SpanDescriptor = .{},
    AttributesSpan: SpanDescriptor = .{},
    StartupSpan: SpanDescriptor = .{},
    JournalInfoCell: u64 = constants.sizes.JOURNAL_INFO_CELL,
    JournalInfoSize: u32 = constants.sizes.JOURNAL_HEADER_SIZE,
    CompressionType: u32 = constants.flags.COMPRESSION_NONE,
    EncryptionType: u32 = constants.flags.ENCRYPTION_NONE,
    Reserved: [64]u8 = [_]u8{0} ** 64,

    pub fn isValid(self: *const VolumeHeader) bool {
        if (self.Signature != constants.magic.SIGNATURE) {
            return false;
        }
        if (self.Version != constants.magic.VERSION) {
            return false;
        }
        if (self.CellSize < constants.sizes.MINIMUM_CELL_SIZE or
            self.CellSize > constants.sizes.MAXIMUM_CELL_SIZE)
        {
            return false;
        }
        return true;
    }
};

pub const SpanDescriptor = extern struct {
    StartCell: u64 = 0,
    CellCount: u64 = 0,

    pub fn isEmpty(self: *const SpanDescriptor) bool {
        return self.CellCount == 0;
    }

    pub fn endCell(self: *const SpanDescriptor) u64 {
        return self.StartCell + self.CellCount;
    }

    pub fn contains(self: *const SpanDescriptor, cell: u64) bool {
        return cell >= self.StartCell and cell < self.endCell();
    }

    pub fn byteSize(self: *const SpanDescriptor, cell_size: u32) u64 {
        return self.CellCount * cell_size;
    }
};

pub const ChannelInfo = extern struct {
    LogicalSize: u64 = 0,
    PhysicalSize: u64 = 0,
    ClumpSize: u32 = 0,
    TotalCells: u32 = 0,
    Spans: [constants.sizes.SPAN_INLINE_COUNT]SpanDescriptor = [_]SpanDescriptor{.{}} ** constants.sizes.SPAN_INLINE_COUNT,

    pub fn getSpan(self: *const ChannelInfo, index: usize) ?*const SpanDescriptor {
        if (index >= constants.sizes.SPAN_INLINE_COUNT) {
            return null;
        }
        if (self.Spans[index].isEmpty()) {
            return null;
        }
        return &self.Spans[index];
    }
};
