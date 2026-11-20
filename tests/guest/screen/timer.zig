//! Free-Running Q35 Diagnostics Clock Before PIT Interrupts

const limits = @import("tests").screen.constants.clock.timer;
const port = @import("asm").io.port;

pub fn locate() ?u16 {
    const previous_address = port.readLong(limits.PCI_ADDRESS);
    defer port.writeLong(limits.PCI_ADDRESS, previous_address);
    if (readConfiguration(limits.LPC_ID_REGISTER) != limits.Q35_LPC_ID) return null;
    if (readConfiguration(limits.LPC_CONTROL_REGISTER) & limits.ACPI_ENABLE == 0) return null;
    const base = readConfiguration(limits.LPC_BASE_REGISTER) & limits.BASE_MASK;
    if (base == 0) return null;
    return @as(u16, @intCast(base)) + limits.TIMER_OFFSET;
}

pub fn read(timer_port: u16) u32 {
    return port.readLong(timer_port) & limits.COUNTER_MASK;
}

fn readConfiguration(register: u32) u32 {
    port.writeLong(limits.PCI_ADDRESS, limits.Q35_LPC_ADDRESS | register);
    return port.readLong(limits.PCI_DATA);
}
