//! GDT Table Type

const entry = @import("entry.zig");
const gdtr = @import("gdtr.zig");
const tss = @import("tss.zig");

pub const Table = extern struct {
    Null: entry.Entry,
    KernelCode: entry.Entry,
    KernelData: entry.Entry,
    UserCode: entry.Entry,
    UserData: entry.Entry,
    TSS: tss.TSSDescriptor align(8),

    pub fn getGDTR(self: *Table) gdtr.GDTR {
        const base = @intFromPtr(self);
        const size = @sizeOf(Table);
        return gdtr.GDTR{
            .Limit = size - 1,
            .Base = base,
        };
    }

    pub fn getEntry(self: *Table, index: u16) ?*entry.Entry {
        const entries: [*]entry.Entry = @ptrCast(self);
        const max_entries = @sizeOf(Table) / @sizeOf(entry.Entry);
        if (index >= max_entries) {
            return null;
        }
        return &entries[index];
    }

    pub fn getTSSDescriptor(self: *Table) *tss.TSSDescriptor {
        return &self.TSS;
    }
};
