//! Physical Memory Statistics

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const Statistics = struct {
    TotalPages: u64 = 0,
    FreePages: u64 = 0,
    UsedPages: u64 = 0,
    ReservedPages: u64 = 0,
    MetadataPages: u64 = 0,
    MetadataBytes: u64 = 0,

    pub fn totalBytes(self: Statistics) u64 {
        return self.TotalPages * sizes.PAGE_SIZE;
    }

    pub fn freeBytes(self: Statistics) u64 {
        return self.FreePages * sizes.PAGE_SIZE;
    }

    pub fn usedBytes(self: Statistics) u64 {
        return self.UsedPages * sizes.PAGE_SIZE;
    }
};
