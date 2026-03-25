//! Hikari Paging Types

const constants = @import("constants.zig");

pub const PageTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    dirty: bool,
    huge_page: bool,
    global: bool,
    available_low: u3,
    address_bits: u40,
    available_high: u11,
    no_execute: bool,

    pub fn empty() PageTableEntry {
        return @bitCast(@as(u64, 0));
    }

    pub fn from_address(address: u64, flags: u64) PageTableEntry {
        const entry: u64 = (address & constants.address_mask) | flags;
        return @bitCast(entry);
    }

    pub fn get_address(self: PageTableEntry) u64 {
        const raw: u64 = @bitCast(self);
        return raw & constants.address_mask;
    }

    pub fn is_present(self: PageTableEntry) bool {
        return self.present;
    }

    pub fn is_huge(self: PageTableEntry) bool {
        return self.huge_page;
    }

    pub fn to_raw(self: PageTableEntry) u64 {
        return @bitCast(self);
    }
};

pub const PageTable = struct {
    entries: [512]PageTableEntry,

    pub fn clear(self: *PageTable) void {
        for (&self.entries) |*entry| {
            entry.* = PageTableEntry.empty();
        }
    }

    pub fn get_entry(self: *PageTable, index: usize) *PageTableEntry {
        return &self.entries[index];
    }

    pub fn set_entry(self: *PageTable, index: usize, entry: PageTableEntry) void {
        self.entries[index] = entry;
    }
};

// Page table levels (L4 = top, L1 = bottom)
pub const TableL4 = PageTable; // PML4
pub const TableL3 = PageTable; // PDPT
pub const TableL2 = PageTable; // PD
pub const TableL1 = PageTable; // PT

pub fn get_l4_index(address: u64) usize {
    return @truncate((address >> constants.pml4_shift) & 0x1FF);
}

pub fn get_l3_index(address: u64) usize {
    return @truncate((address >> constants.pdpt_shift) & 0x1FF);
}

pub fn get_l2_index(address: u64) usize {
    return @truncate((address >> constants.pd_shift) & 0x1FF);
}

pub fn get_l1_index(address: u64) usize {
    return @truncate((address >> constants.pt_shift) & 0x1FF);
}

pub fn get_page_offset(address: u64) usize {
    return @truncate(address & 0xFFF);
}
