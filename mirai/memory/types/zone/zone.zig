//! Zone Types

pub const Zone = struct {
    name: [32]u8,
    name_len: u8,
    elem_size: usize,
    elems_per_page: usize,
    partial_pages: ?*ZonePageMeta,
    full_pages: ?*ZonePageMeta,
    alloc_count: usize,
    free_count: usize,
    page_count: usize,

    pub fn get_name(self: *const Zone) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn in_use(self: *const Zone) usize {
        return self.alloc_count -| self.free_count;
    }
};

pub const FreeElement = struct {
    next: ?*FreeElement,
};

pub const ZonePageMeta = struct {
    zone: *Zone,
    page_virt: u64,
    page_phys: u64,
    free_list: ?*FreeElement,
    in_use: usize,
    next: ?*ZonePageMeta,
};

pub const page_size: usize = 4096;
pub const min_elem_size: usize = @sizeOf(FreeElement);
