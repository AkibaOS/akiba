//! Extract Physical Address

const types = @import("../types/types.zig");
const tables = @import("../tables/tables.zig");

const Entry = types.Entry;
const Kagami = types.Kagami;

pub fn extract(kagami: *const Kagami, virtual_address: u64) ?u64 {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse return null;

    if (!entry.is_present()) {
        return null;
    }

    const physical_base = entry.get_physical_address();
    const offset = virtual_address & 0xFFF;

    return physical_base | offset;
}

pub fn is_mapped(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse return false;
    return entry.is_present();
}

pub fn is_writable(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse return false;
    return entry.is_present() and entry.is_writable();
}

pub fn is_user_accessible(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse return false;
    return entry.is_present() and entry.is_user();
}
