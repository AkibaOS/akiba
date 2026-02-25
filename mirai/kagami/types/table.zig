//! Page Table Type

const Entry = @import("entry.zig").Entry;

pub const Table = struct {
    entries: [512]Entry,

    pub fn get_entry(self: *Table, index: u9) *Entry {
        return &self.entries[index];
    }

    pub fn get_entry_const(self: *const Table, index: u9) *const Entry {
        return &self.entries[index];
    }

    pub fn clear_all(self: *Table) void {
        for (&self.entries) |*entry| {
            entry.clear();
        }
    }

    pub fn copy_kernel_entries(self: *Table, source: *const Table) void {
        var index: usize = 256;
        while (index < 512) : (index += 1) {
            self.entries[index] = source.entries[index];
        }
    }

    pub fn count_present(self: *const Table) u32 {
        var count: u32 = 0;
        for (self.entries) |entry| {
            if (entry.is_present()) {
                count += 1;
            }
        }
        return count;
    }
};
