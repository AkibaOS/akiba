//! Hikari Block I/O Media Snapshot

const efi = @import("hikari").efi;

const BlockIoProtocol = efi.types.protocols.block.BlockIoProtocol;

pub const MediaSnapshot = struct {
    BlockIO: *BlockIoProtocol,
    MediaId: u32,
    BlockSize: u32,
    IOAlign: u32,
    LastBlock: u64,
    LogicalPartition: bool,

    pub fn capture(block_io: *BlockIoProtocol) ?MediaSnapshot {
        const media = block_io.Media;
        if (!media.MediaPresent) return null;
        return .{
            .BlockIO = block_io,
            .MediaId = media.MediaId,
            .BlockSize = media.BlockSize,
            .IOAlign = media.IOAlign,
            .LastBlock = media.LastBlock,
            .LogicalPartition = media.LogicalPartition,
        };
    }

    pub fn isCurrent(self: MediaSnapshot) bool {
        const current = self.BlockIO.Media;
        return current.MediaPresent and current.MediaId == self.MediaId and
            current.BlockSize == self.BlockSize and current.IOAlign == self.IOAlign and
            current.LastBlock == self.LastBlock and current.LogicalPartition == self.LogicalPartition;
    }

    pub fn read(self: MediaSnapshot, lba: u64, buffer: []u8) bool {
        if (self.BlockSize == 0 or buffer.len == 0 or buffer.len % self.BlockSize != 0 or
            lba > self.LastBlock or buffer.len / self.BlockSize - 1 > self.LastBlock - lba or
            @intFromPtr(buffer.ptr) % @max(self.IOAlign, 1) != 0 or !self.isCurrent())
        {
            return false;
        }
        const status = self.BlockIO.ReadBlocks(self.BlockIO, self.MediaId, lba, buffer.len, buffer.ptr);
        return !efi.status.isError(status) and self.isCurrent();
    }
};
