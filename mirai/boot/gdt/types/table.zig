//! GDT Table Type

const Entry = @import("entry.zig").Entry;
const TssDescriptor = @import("tss_descriptor.zig").TssDescriptor;
const Gdtr = @import("gdtr.zig").Gdtr;

pub const Table = extern struct {
    null: Entry,
    kernel_code: Entry,
    kernel_data: Entry,
    user_code: Entry,
    user_data: Entry,
    tss: TssDescriptor,

    pub fn get_gdtr(self: *Table) Gdtr {
        const base = @intFromPtr(self);
        const size = @sizeOf(Table);
        return Gdtr{
            .limit = size - 1,
            .base = base,
        };
    }

    pub fn get_entry(self: *Table, index: u16) ?*Entry {
        const entries: [*]Entry = @ptrCast(self);
        const max_entries = @sizeOf(Table) / @sizeOf(Entry);
        if (index >= max_entries) {
            return null;
        }
        return &entries[index];
    }

    pub fn get_tss_descriptor(self: *Table) *TssDescriptor {
        return &self.tss;
    }
};
