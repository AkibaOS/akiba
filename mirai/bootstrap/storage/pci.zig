//! Bootstrap PCI Configuration Access At A Discovered Address

const fields = @import("shared").ahci.constants.discover.pci;
const port = @import("asm").io.port;
const values = @import("mirai").bootstrap.constants.storage.pci;

const Address = @import("shared").ahci.types.discover.configuration.Address;
const Source = @import("shared").ahci.types.discover.configuration.Source;

pub fn source() Source {
    return .{ .Read = read };
}

pub fn commandBits(address: Address, command: u16) void {
    const previous = port.readLong(values.ADDRESS_PORT);
    defer port.writeLong(values.ADDRESS_PORT, previous);
    port.writeLong(values.ADDRESS_PORT, selector(address, fields.COMMAND_OFFSET));
    port.writeWord(values.DATA_PORT, command);
}

fn read(_: ?*anyopaque, address: Address, register: u8) u32 {
    const previous = port.readLong(values.ADDRESS_PORT);
    defer port.writeLong(values.ADDRESS_PORT, previous);
    port.writeLong(values.ADDRESS_PORT, selector(address, register));
    return port.readLong(values.DATA_PORT);
}

fn selector(address: Address, register: u8) u32 {
    const location: u16 = @bitCast(address);
    return values.ENABLE | (@as(u32, location) << values.ADDRESS_SHIFT) | register;
}
