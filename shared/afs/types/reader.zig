//! Bounded Read Only AFS Catalog View

const afs = @import("shared").afs;

const BlockReader = afs.types.block.BlockReader;
const HeaderRecord = afs.types.btree.HeaderRecord;
const SpanDescriptor = afs.types.volume.SpanDescriptor;

pub const Catalog = struct {
    Reader: BlockReader,
    Index: HeaderRecord,
    Span: SpanDescriptor,
};
