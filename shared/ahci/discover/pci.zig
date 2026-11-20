//! Discover Configured AHCI Functions Without A Chipset Identity

const fields = @import("shared").ahci.constants.discover.pci;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").ahci.types.discover;

const Address = types.configuration.Address;
const Controller = types.controller.Controller;
const Cursor = types.configuration.Cursor;
const DiscoverError = @import("shared").ahci.errors.discover.selection.DiscoverError;
const Source = types.configuration.Source;

pub fn next(source: Source, cursor: *Cursor) DiscoverError!?Controller {
    while (cursor.Next < fields.ADDRESS_COUNT) {
        const key: u16 = @intCast(cursor.Next);
        const address: Address = @bitCast(key);
        const vendor: u16 = @truncate(source.Read(source.Context, address, fields.IDENTIFIER_OFFSET));
        if (vendor == fields.ABSENT_VENDOR or vendor == 0) {
            cursor.Next += if (address.Function == 0) fields.FUNCTIONS_PER_SLOT else 1;
            continue;
        }
        const header: u8 = @truncate(source.Read(source.Context, address, fields.HEADER_OFFSET) >> fields.HEADER_SHIFT);
        cursor.Next += if (address.Function == 0 and header & fields.MULTIFUNCTION == 0) fields.FUNCTIONS_PER_SLOT else 1;
        if (source.Read(source.Context, address, fields.CLASS_OFFSET) >> fields.CLASS_SHIFT != fields.AHCI_CLASS) continue;
        if (header & fields.HEADER_KIND != fields.TYPE_ZERO) return error.InvalidAhciFunction;
        return try aperture(source, address);
    }
    return null;
}

fn aperture(source: Source, address: Address) DiscoverError!Controller {
    const command: u16 = @truncate(source.Read(source.Context, address, fields.COMMAND_OFFSET));
    const bar = source.Read(source.Context, address, fields.BAR_OFFSET);
    if (command & fields.MEMORY_ENABLE == 0 or bar == 0 or bar & sizes.PAGE_MASK != 0) return error.InvalidAhciBar;
    return .{ .Address = address, .Bar = bar, .Command = command };
}
