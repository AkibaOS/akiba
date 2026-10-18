//! Owned Four Kilobyte Mapping Protection

const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const policy = @import("mirai").kagami.policy;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const MappingError = common.errors.memory.mapping.MappingError;
const sizes = common.constants.memory.sizes;
const Kagami = types.kagami.Kagami;

pub fn protect(kagami: *Kagami, virtual_address: u64, protection: u8) MappingError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try policy.canMutate(kagami, virtual_address);
    const entry = tables.walk.walkToOwnedEntry(kagami.PML4Physical, virtual_address) orelse return MappingError.NotMapped;
    if (!entry.Present) return MappingError.NotMapped;
    try policy.validateMapping(kagami, virtual_address, entry.getPhysicalAddress(), protection);
    const was_wired = entry.isWired();
    tables.attributes.apply(entry, protection);
    if (was_wired != entry.isWired()) {
        if (was_wired) kagami.removeWired() else kagami.addWired();
    }
    cpu.control.invalidatePage(virtual_address);
}

pub fn protectRange(kagami: *Kagami, start_address: u64, page_count: u64, protection: u8) u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    var protected_count: u64 = 0;
    var offset: u64 = 0;
    var virtual_address = start_address;
    while (offset < page_count) : (offset += 1) {
        if (protect(kagami, virtual_address, protection)) |_| {
            protected_count += 1;
        } else |_| {}
        const next = @addWithOverflow(virtual_address, sizes.PAGE_SIZE);
        if (next[1] != 0) break;
        virtual_address = next[0];
    }
    return protected_count;
}
