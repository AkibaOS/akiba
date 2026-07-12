//! Change Protection

const common = @import("root").common;
const types = @import("../types/types.zig");
const tables = @import("../tables/tables.zig");
const constants = @import("../constants/constants.zig");
const asm_cpu = @import("asm").cpu;

const MappingError = common.errors.memory.MappingError;
const Entry = types.Entry;
const Kagami = types.Kagami;

pub fn protect(kagami: *Kagami, virtual_address: u64, protection: u8) MappingError!void {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse {
        return MappingError.NotMapped;
    };

    if (!entry.is_present()) {
        return MappingError.NotMapped;
    }

    entry.writable = (protection & constants.protection.write) != 0;
    entry.user_accessible = (protection & constants.protection.user) != 0;
    entry.cache_disabled = (protection & constants.protection.nocache) != 0;
    entry.no_execute = (protection & constants.protection.execute) == 0;

    asm_cpu.invalidate_page(virtual_address);
}

pub fn protect_range(kagami: *Kagami, start_address: u64, page_count: u64, protection: u8) u64 {
    var protected_count: u64 = 0;
    var offset: u64 = 0;

    while (offset < page_count) : (offset += 1) {
        const virtual_address = start_address + (offset * 4096);
        protect(kagami, virtual_address, protection) catch continue;
        protected_count += 1;
    }

    return protected_count;
}
