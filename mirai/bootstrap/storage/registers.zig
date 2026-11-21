//! Boot AHCI MMIO And Port Drain

const cpu = @import("asm").cpu;
const limits = @import("mirai").bootstrap.constants.storage.limits;
const portspec = @import("shared").ahci.discover.port;
const values = @import("mirai").bootstrap.constants.storage.registers;

const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;

pub fn stop(sata: u64) bool {
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.START);
    if (!waitClear(sata, values.COMMAND, values.RUNNING_COMMAND)) return false;
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.RECEIVE_FIS);
    return waitClear(sata, values.COMMAND, values.RUNNING_FIS);
}

pub fn ports(controller: u64) StorageError!u32 {
    const count = (read(controller, values.CAP) & values.PORT_NUMBER_MASK) + 1;
    if (count > values.MAPPED_PORTS) return StorageError.UnsupportedAhciController;
    const valid = (@as(u32, 1) << @as(u5, @intCast(count))) - 1;
    const implemented = read(controller, values.PORTS);
    if (implemented & ~valid != 0) return StorageError.UnsupportedAhciController;
    return implemented;
}

pub fn diskPort(controller: u64, index: u5) StorageError!?u64 {
    if (index >= values.MAPPED_PORTS) return StorageError.UnsupportedAhciPort;
    const sata = controller + values.PORT_BASE + @as(u64, index) * values.PORT_STRIDE;
    return switch (portspec.classify(read(sata, values.LINK), read(sata, values.SIGNATURE))) {
        .Empty, .PacketDevice => null,
        .AtaDisk => sata,
        .Unverifiable => StorageError.UnsupportedAhciPort,
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
