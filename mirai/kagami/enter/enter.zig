//! Owned Four Kilobyte Mapping Insertion

const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const policy = @import("mirai").kagami.policy;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;
const Kagami = types.kagami.Kagami;

pub fn enter(kagami: *Kagami, virtual_address: u64, physical_address: u64, protection: u8) (MappingError || AllocationError)!void {
    return insert(kagami, virtual_address, physical_address, protection, false);
}

pub fn enterReplace(kagami: *Kagami, virtual_address: u64, physical_address: u64, protection: u8) (MappingError || AllocationError)!void {
    return insert(kagami, virtual_address, physical_address, protection, true);
}

fn insert(kagami: *Kagami, virtual_address: u64, physical_address: u64, protection: u8, replace: bool) (MappingError || AllocationError)!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try policy.validateMapping(kagami, virtual_address, physical_address, protection);
    const entry = try tables.allocate.ensureTables(kagami, virtual_address);
    const was_present = entry.Present;
    if (was_present and !replace) return MappingError.AlreadyMapped;
    const was_wired = was_present and entry.isWired();
    entry.* = tables.attributes.make(physical_address, protection);
    if (!was_present) kagami.addResident();
    if (was_wired != entry.isWired()) {
        if (was_wired) kagami.removeWired() else kagami.addWired();
    }
    cpu.control.invalidatePage(virtual_address);
}
