//! Hikari Page Table Type

const common = @import("common");

const entry = @import("entry.zig");

const sizes = common.constants.memory.sizes;

pub const PageTable = struct {
    Entries: [sizes.ENTRIES_PER_PAGE_TABLE]entry.PageTableEntry,

    pub fn clear(self: *PageTable) void {
        for (&self.Entries) |*table_entry| {
            table_entry.* = entry.PageTableEntry.empty();
        }
    }

    pub fn getEntry(self: *PageTable, index: usize) *entry.PageTableEntry {
        return &self.Entries[index];
    }

    pub fn setEntry(self: *PageTable, index: usize, value: entry.PageTableEntry) void {
        self.Entries[index] = value;
    }
};

pub const TableL4 = PageTable;
pub const TableL3 = PageTable;
pub const TableL2 = PageTable;
pub const TableL1 = PageTable;
