//! Q35 Fixture MMIO Access And Port Drain

const cpu = @import("asm").cpu;
const limits = @import("tests").guest.constants.ahci.limits;
const sizes = @import("common").constants.memory.sizes;
const values = @import("tests").guest.constants.ahci.registers;

const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;

pub fn stop(sata: u64) bool {
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.START);
    if (!waitClear(sata, values.COMMAND, values.RUNNING_COMMAND)) return false;
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.RECEIVE_FIS);
    return waitClear(sata, values.COMMAND, values.RUNNING_FIS);
}

pub fn selectPort(controller: u64) !u64 {
    const count = (read(controller, values.CAP) & values.PORT_NUMBER_MASK) + 1;
    if (count > (sizes.PAGE_SIZE - values.PORT_BASE) / values.PORT_STRIDE) return ProbeError.UnsupportedAhciController;
    const implemented = read(controller, values.PORTS);
    var selected: ?u64 = null;
    for (0..count) |index| {
        if (implemented & (@as(u32, 1) << @intCast(index)) == 0) continue;
        const sata = controller + values.PORT_BASE + index * values.PORT_STRIDE;
        const link = read(sata, values.LINK);
        if (link & values.LINK_PRESENT_MASK != values.LINK_PRESENT) continue;
        if (selected != null or link & values.LINK_ACTIVE_MASK != values.LINK_ACTIVE or read(sata, values.SIGNATURE) != values.ATA_SIGNATURE)
            return ProbeError.UnsupportedAhciPort;
        selected = sata;
    }
    return selected orelse ProbeError.AhciDiskMissing;
}

pub fn waitClear(base: u64, register: u64, mask: u32) bool {
    for (0..limits.POLL_LIMIT) |_| {
        if (read(base, register) & mask == 0) return true;
        cpu.halt.pause();
    }
    return false;
}

pub fn read(base: u64, register: u64) u32 {
    const address: *const volatile u32 = @ptrFromInt(base + register);
    return address.*;
}

pub fn write(base: u64, register: u64, value: u32) void {
    const address: *volatile u32 = @ptrFromInt(base + register);
    address.* = value;
}
