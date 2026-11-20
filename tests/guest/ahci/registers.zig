//! Q35 Fixture MMIO Access And Port Drain

const cpu = @import("asm").cpu;
const limits = @import("tests").guest.constants.ahci.limits;
const values = @import("tests").guest.constants.ahci.registers;

const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;

pub fn stop(sata: u64) bool {
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.START);
    if (!waitClear(sata, values.COMMAND, values.RUNNING_COMMAND)) return false;
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.RECEIVE_FIS);
    return waitClear(sata, values.COMMAND, values.RUNNING_FIS);
}

pub fn ports(controller: u64) ProbeError!u32 {
    const count = (read(controller, values.CAP) & values.PORT_NUMBER_MASK) + 1;
    if (count > values.MAPPED_PORTS) return ProbeError.UnsupportedAhciController;
    const valid = (@as(u32, 1) << @as(u5, @intCast(count))) - 1;
    const implemented = read(controller, values.PORTS);
    if (implemented & ~valid != 0) return ProbeError.UnsupportedAhciController;
    return implemented;
}

pub fn diskPort(controller: u64, index: u5) ProbeError!?u64 {
    if (index >= values.MAPPED_PORTS) return ProbeError.UnsupportedAhciPort;
    const sata = controller + values.PORT_BASE + @as(u64, index) * values.PORT_STRIDE;
    const link = read(sata, values.LINK);
    const presence = link & values.LINK_PRESENT_MASK;
    if (presence == 0) return null;
    if (presence != values.LINK_PRESENT or link & values.LINK_ACTIVE_MASK != values.LINK_ACTIVE or read(sata, values.SIGNATURE) != values.ATA_SIGNATURE)
        return ProbeError.UnsupportedAhciPort;
    return sata;
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
