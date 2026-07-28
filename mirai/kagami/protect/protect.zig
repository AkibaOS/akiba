//! Change Protection

const common = @import("common");

const cpu = @import("asm").cpu;

const constants = @import("mirai").kagami.constants;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const MappingError = common.errors.memory.mapping.MappingError;
const sizes = common.constants.memory.sizes;

const Kagami = types.kagami.Kagami;

pub fn protect(kagami: *Kagami, virtual_address: u64, protection: u8) MappingError!void {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse {
        return MappingError.NotMapped;
    };

    if (!entry.isPresent()) {
        return MappingError.NotMapped;
    }

    entry.Writable = (protection & constants.protection.WRITE) != 0;
    entry.UserAccessible = (protection & constants.protection.USER) != 0;
    entry.CacheDisabled = (protection & constants.protection.NOCACHE) != 0;
    entry.NoExecute = (protection & constants.protection.EXECUTE) == 0;

    cpu.control.invalidatePage(virtual_address);
}

pub fn protectRange(kagami: *Kagami, start_address: u64, page_count: u64, protection: u8) u64 {
    var protected_count: u64 = 0;
    var offset: u64 = 0;

    while (offset < page_count) : (offset += 1) {
        const virtual_address = start_address + (offset * sizes.PAGE_SIZE);
        protect(kagami, virtual_address, protection) catch continue;
        protected_count += 1;
    }

    return protected_count;
}
