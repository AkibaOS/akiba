//! Retain Controller Failure State Without Affecting Other Controllers

const codec = @import("shared").ahci.discover.location;
const fields = @import("shared").ahci.constants.discover.pci;
const guard = @import("asm").interrupts.guard;
const instances = @import("mirai").device.instance.registry;
const registers = @import("mirai").device.constants.ahci.registers;

const Address = @import("shared").ahci.types.discover.configuration.Address;

var blocked: [fields.ADDRESS_COUNT]bool = @splat(false);

pub fn contains(address: Address) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    return blocked[@as(u16, @bitCast(address))];
}

pub fn retain(address: Address) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    blocked[@as(u16, @bitCast(address))] = true;
    for (0..registers.MAPPED_PORTS) |port| {
        const key = codec.encode(.{ .Address = address, .Port = @intCast(port) });
        if (instances.find(.Ahci, key)) |identifier| instances.disable(identifier);
    }
}
