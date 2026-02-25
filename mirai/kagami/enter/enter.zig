//! Enter Mapping (VA -> PA)

const common = @import("../../../common/common.zig");
const types = @import("../types/types.zig");
const tables = @import("../tables/tables.zig");
const constants = @import("../constants/constants.zig");
const asm_cpu = @import("../../asm/cpu/cpu.zig");

const paging_flags = common.constants.paging.flags;
const MappingError = common.errors.memory.MappingError;
const AllocationError = common.errors.memory.AllocationError;

const Entry = types.Entry;
const Kagami = types.Kagami;

pub fn enter(
    kagami: *Kagami,
    virtual_address: u64,
    physical_address: u64,
    protection: u8,
) (MappingError || AllocationError)!void {
    if ((virtual_address & 0xFFF) != 0) {
        return MappingError.AddressNotAligned;
    }

    if ((physical_address & 0xFFF) != 0) {
        return MappingError.AddressNotAligned;
    }

    const entry = try tables.ensure_tables(kagami, virtual_address);

    if (entry.is_present()) {
        return MappingError.AlreadyMapped;
    }

    entry.* = build_entry(physical_address, protection);

    kagami.add_resident();

    if ((protection & constants.protection.wired) != 0) {
        kagami.add_wired();
    }

    asm_cpu.invalidate_page(virtual_address);
}

pub fn enter_replace(
    kagami: *Kagami,
    virtual_address: u64,
    physical_address: u64,
    protection: u8,
) (MappingError || AllocationError)!void {
    if ((virtual_address & 0xFFF) != 0) {
        return MappingError.AddressNotAligned;
    }

    if ((physical_address & 0xFFF) != 0) {
        return MappingError.AddressNotAligned;
    }

    const entry = try tables.ensure_tables(kagami, virtual_address);

    const was_present = entry.is_present();

    entry.* = build_entry(physical_address, protection);

    if (!was_present) {
        kagami.add_resident();
    }

    asm_cpu.invalidate_page(virtual_address);
}

fn build_entry(physical_address: u64, protection: u8) Entry {
    var entry = Entry{
        .present = true,
        .writable = (protection & constants.protection.write) != 0,
        .user_accessible = (protection & constants.protection.user) != 0,
        .cache_disabled = (protection & constants.protection.nocache) != 0,
        .global = (protection & constants.protection.user) == 0,
        .no_execute = (protection & constants.protection.execute) == 0,
    };

    entry.set_physical_address(physical_address);

    return entry;
}
