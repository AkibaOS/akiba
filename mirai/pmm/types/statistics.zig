//! Physical Memory Statistics

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const Statistics = struct {
    TotalPages: u64,
    FreePages: u64,
    UsedPages: u64,
    ReservedPages: u64,
    WiredPages: u64,

    pub fn totalBytes(self: Statistics) u64 {
        return self.TotalPages * sizes.PAGE_SIZE;
    }

    pub fn freeBytes(self: Statistics) u64 {
        return self.FreePages * sizes.PAGE_SIZE;
    }

    pub fn usedBytes(self: Statistics) u64 {
        return self.UsedPages * sizes.PAGE_SIZE;
    }

    pub fn usagePercentage(self: Statistics) u8 {
        if (self.TotalPages == 0) return 0;
        return @truncate((self.UsedPages * 100) / self.TotalPages);
    }
};
