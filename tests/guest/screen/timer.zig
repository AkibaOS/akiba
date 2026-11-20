//! Free-Running Q35 Diagnostics Clock Before PIT Interrupts

const hardware = @import("tests").guest.constants.screen.lpc;
const port = @import("asm").io.port;
const timer = @import("tests").screen.constants.clock.timer;

pub fn locate() ?u16 {
    const previous_address = port.readLong(hardware.PCI_ADDRESS);
    defer port.writeLong(hardware.PCI_ADDRESS, previous_address);
    if (readConfiguration(hardware.LPC_ID_REGISTER) != hardware.Q35_LPC_ID) return null;
    if (readConfiguration(hardware.LPC_CONTROL_REGISTER) & hardware.ACPI_ENABLE == 0) return null;
    const base = readConfiguration(hardware.LPC_BASE_REGISTER) & hardware.BASE_MASK;
    if (base == 0) return null;
    return @as(u16, @intCast(base)) + hardware.TIMER_OFFSET;
}

pub fn read(timer_port: u16) u32 {
    return port.readLong(timer_port) & timer.COUNTER_MASK;
}

fn readConfiguration(register: u32) u32 {
    port.writeLong(hardware.PCI_ADDRESS, hardware.Q35_LPC_ADDRESS | register);
    return port.readLong(hardware.PCI_DATA);
}
