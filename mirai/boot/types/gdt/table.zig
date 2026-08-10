//! GDT Table Type

const entry = @import("mirai").boot.types.gdt.entry;
const gdtr = @import("mirai").boot.types.gdt.gdtr;
const tss = @import("mirai").boot.types.gdt.tss;

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
};
