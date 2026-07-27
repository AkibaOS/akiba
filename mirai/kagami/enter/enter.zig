//! Enter Mapping (VA -> PA)

const common = @import("common");

const cpu = @import("asm").cpu;

const constants = @import("../constants/constants.zig");
const tables = @import("../tables/tables.zig");
const types = @import("../types/types.zig");

const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;
const sizes = common.constants.memory.sizes;

const Entry = types.entry.Entry;
const Kagami = types.kagami.Kagami;

pub fn enter(
    kagami: *Kagami,
    virtual_address: u64,
    physical_address: u64,
    protection: u8,
) (MappingError || AllocationError)!void {
    if ((virtual_address & sizes.PAGE_MASK) != 0) {
        return MappingError.AddressNotAligned;
    }

    if ((physical_address & sizes.PAGE_MASK) != 0) {
        return MappingError.AddressNotAligned;
    }

    const entry = try tables.allocate.ensureTables(kagami, virtual_address);

    if (entry.isPresent()) {
        return MappingError.AlreadyMapped;
    }

    entry.* = buildEntry(physical_address, protection);

    kagami.addResident();

    if ((protection & constants.protection.WIRED) != 0) {
        kagami.addWired();
    }

    cpu.control.invalidatePage(virtual_address);
}

pub fn enterReplace(
    kagami: *Kagami,
    virtual_address: u64,
    physical_address: u64,
    protection: u8,
) (MappingError || AllocationError)!void {
    if ((virtual_address & sizes.PAGE_MASK) != 0) {
        return MappingError.AddressNotAligned;
    }

    if ((physical_address & sizes.PAGE_MASK) != 0) {
        return MappingError.AddressNotAligned;
    }

    const entry = try tables.allocate.ensureTables(kagami, virtual_address);

    const was_present = entry.isPresent();

    entry.* = buildEntry(physical_address, protection);

    if (!was_present) {
        kagami.addResident();
    }

    cpu.control.invalidatePage(virtual_address);
}

fn buildEntry(physical_address: u64, protection: u8) Entry {
    var entry = Entry{
        .Present = true,
        .Writable = (protection & constants.protection.WRITE) != 0,
        .UserAccessible = (protection & constants.protection.USER) != 0,
        .CacheDisabled = (protection & constants.protection.NOCACHE) != 0,
        .Global = (protection & constants.protection.USER) == 0,
        .NoExecute = (protection & constants.protection.EXECUTE) == 0,
    };

    entry.setPhysicalAddress(physical_address);

    return entry;
}
