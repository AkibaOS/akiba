//! Identify The Expected Q35 SATA Fixture

const port = @import("asm").io.port;
const values = @import("tests").guest.constants.ahci.pci;

const Controller = @import("tests").guest.types.ahci.Controller;
const ProbeError = @import("tests").guest.errors.ahci.ProbeError;

pub fn controller() ProbeError!Controller {
    if (pci(values.PCI_ID) != values.ICH9_ID or pci(values.PCI_CLASS) >> values.REVISION_BITS != values.AHCI_CLASS)
        return ProbeError.AhciControllerMissing;
    const command: u16 = @truncate(pci(values.PCI_COMMAND));
    const bar = pci(values.PCI_BAR);
    if (command & values.MEMORY_ENABLE == 0 or bar == 0 or bar & values.BAR_FLAGS != 0) return ProbeError.InvalidAhciBar;
    return .{ .Bar = bar, .Command = command };
}

fn pci(register: u32) u32 {
    port.writeLong(values.PCI_ADDRESS, values.ICH9_ADDRESS | register);
    return port.readLong(values.PCI_DATA);
}

pub fn commandBits(command: u16) void {
    port.writeLong(values.PCI_ADDRESS, values.ICH9_ADDRESS | values.PCI_COMMAND);
    port.writeWord(values.PCI_DATA, command);
}
