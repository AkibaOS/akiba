//! Checked AHCI MMIO And Port Drain

const cpu = @import("asm").cpu;
const limits = @import("mirai").device.constants.ahci.limits;
const portspec = @import("shared").ahci.discover.port;
const values = @import("mirai").device.constants.ahci.registers;

const AttachmentError = @import("mirai").device.errors.ahci.attachment.AttachmentError;

pub fn detached(sata: u64) bool {
    const engine = values.START | values.RECEIVE_FIS | values.RUNNING_COMMAND | values.RUNNING_FIS;
    return read(sata, values.COMMAND) & engine == 0 and read(sata, values.ISSUE) == 0 and read(sata, values.ACTIVE) == 0 and
        read(sata, values.LIST) == 0 and read(sata, values.LIST_HIGH) == 0 and
        read(sata, values.FIS) == 0 and read(sata, values.FIS_HIGH) == 0;
}

pub fn stop(sata: u64) bool {
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.START);
    if (!waitClear(sata, values.COMMAND, values.RUNNING_COMMAND)) return false;
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.RECEIVE_FIS);
    return waitClear(sata, values.COMMAND, values.RUNNING_FIS);
}

pub fn ports(controller: u64) AttachmentError!u32 {
    const count = (read(controller, values.CAP) & values.PORT_NUMBER_MASK) + 1;
    if (count > values.MAPPED_PORTS) return AttachmentError.UnsupportedAhciController;
    const valid = (@as(u32, 1) << @as(u5, @intCast(count))) - 1;
    const implemented = read(controller, values.PORTS);
    if (implemented & ~valid != 0) return AttachmentError.UnsupportedAhciController;
    return implemented;
}

pub fn diskPort(controller: u64, index: u5) AttachmentError!?u64 {
    if (index >= values.MAPPED_PORTS) return AttachmentError.UnsupportedAhciPort;
    const sata = controller + values.PORT_BASE + @as(u64, index) * values.PORT_STRIDE;
    return switch (portspec.classify(read(sata, values.LINK), read(sata, values.SIGNATURE))) {
        .Empty, .PacketDevice => null,
        .AtaDisk => sata,
        .Unverifiable => AttachmentError.UnsupportedAhciPort,
    };
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
