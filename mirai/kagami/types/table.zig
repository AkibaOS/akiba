//! Page Table Type

const common = @import("common");

const entry = @import("mirai").kagami.types.entry;

const constants = @import("mirai").kagami.constants;
const sizes = common.constants.memory.sizes;

pub const Table = struct {
    Entries: [sizes.ENTRIES_PER_PAGE_TABLE]entry.Entry,

    pub fn getEntry(self: *Table, index: u9) *entry.Entry {
        return &self.Entries[index];
    }

    pub fn getEntryConst(self: *const Table, index: u9) *const entry.Entry {
        return &self.Entries[index];
    }

    pub fn clearAll(self: *Table) void {
        for (&self.Entries) |*table_entry| {
            table_entry.clear();
        }
    }

    pub fn copyKernelEntries(self: *Table, source: *const Table) void {
        var index: usize = constants.tables.KERNEL_PML4_START;
        while (index < constants.tables.KERNEL_PML4_END) : (index += 1) {
            self.Entries[index] = source.Entries[index];
        }
    }

    pub fn countPresent(self: *const Table) u32 {
        var count: u32 = 0;
        for (self.Entries) |table_entry| {
            if (table_entry.isPresent()) {
                count += 1;
            }
        }
        return count;
    }
};
