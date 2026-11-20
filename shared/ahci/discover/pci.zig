//! Discover Configured AHCI Functions Without A Chipset Identity

const fields = @import("shared").ahci.constants.discover.pci;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").ahci.types.discover;

const Address = types.configuration.Address;
const Controller = types.controller.Controller;
const Cursor = types.configuration.Cursor;
const DiscoverError = @import("shared").ahci.errors.discover.selection.DiscoverError;
const Source = types.configuration.Source;

pub fn inspect(source: Source, address: Address) DiscoverError!?Controller {
    if (address.Function != 0) {
        var primary = address;
        primary.Function = 0;
        if (!present(source, primary) or headerKind(source, primary) & fields.MULTIFUNCTION == 0) return null;
    }
    if (!present(source, address)) return null;
    return candidate(source, address, headerKind(source, address));
}

pub fn next(source: Source, cursor: *Cursor) DiscoverError!?Controller {
    while (cursor.Next < fields.ADDRESS_COUNT) {
        const key: u16 = @intCast(cursor.Next);
        const address: Address = @bitCast(key);
        if (!present(source, address)) {
            cursor.Next += if (address.Function == 0) fields.FUNCTIONS_PER_SLOT else 1;
            continue;
        }
        const header = headerKind(source, address);
        cursor.Next += if (address.Function == 0 and header & fields.MULTIFUNCTION == 0) fields.FUNCTIONS_PER_SLOT else 1;
        if (try candidate(source, address, header)) |device| return device;
    }
    return null;
}

fn present(source: Source, address: Address) bool {
    const vendor: u16 = @truncate(source.Read(source.Context, address, fields.IDENTIFIER_OFFSET));
    return vendor != fields.ABSENT_VENDOR and vendor != 0;
}

fn headerKind(source: Source, address: Address) u8 {
    return @truncate(source.Read(source.Context, address, fields.HEADER_OFFSET) >> fields.HEADER_SHIFT);
}

fn candidate(source: Source, address: Address, header: u8) DiscoverError!?Controller {
    if (source.Read(source.Context, address, fields.CLASS_OFFSET) >> fields.CLASS_SHIFT != fields.AHCI_CLASS) return null;
    if (header & fields.HEADER_KIND != fields.TYPE_ZERO) return error.InvalidAhciFunction;
    const command: u16 = @truncate(source.Read(source.Context, address, fields.COMMAND_OFFSET));
    const bar = source.Read(source.Context, address, fields.BAR_OFFSET);
    if (command & fields.MEMORY_ENABLE == 0 or bar == 0 or bar & sizes.PAGE_MASK != 0) return error.InvalidAhciBar;
    return .{ .Address = address, .Bar = bar, .Command = command };
}
