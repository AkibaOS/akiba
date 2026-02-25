//! Physical Memory Statistics

pub const Statistics = struct {
    total_pages: u64,
    free_pages: u64,
    used_pages: u64,
    reserved_pages: u64,
    wired_pages: u64,

    pub fn total_bytes(self: Statistics) u64 {
        return self.total_pages * 4096;
    }

    pub fn free_bytes(self: Statistics) u64 {
        return self.free_pages * 4096;
    }

    pub fn used_bytes(self: Statistics) u64 {
        return self.used_pages * 4096;
    }

    pub fn usage_percentage(self: Statistics) u8 {
        if (self.total_pages == 0) return 0;
        return @truncate((self.used_pages * 100) / self.total_pages);
    }
};
