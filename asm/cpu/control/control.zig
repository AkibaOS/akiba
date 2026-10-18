//! CPU Control Register Operations

const constants = @import("asm").cpu.constants.control;
const strings = @import("asm").cpu.strings.control;

pub fn readCR0() u64 {
    var result: u64 = undefined;
    asm volatile (strings.READ_CR0
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR0(value: u64) void {
    asm volatile (strings.WRITE_CR0
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub fn readCR2() u64 {
    var result: u64 = undefined;
    asm volatile (strings.READ_CR2
        : [result] "=r" (result),
    );
    return result;
}

pub fn readCR3() u64 {
    var result: u64 = undefined;
    asm volatile (strings.READ_CR3
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR3(value: u64) void {
    asm volatile (strings.WRITE_CR3
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub fn readCR4() u64 {
    var result: u64 = undefined;
    asm volatile (strings.READ_CR4
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR4(value: u64) void {
    asm volatile (strings.WRITE_CR4
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub fn enableWriteProtect() bool {
    writeCR0(readCR0() | constants.CR0_WRITE_PROTECT);
    return (readCR0() & constants.CR0_WRITE_PROTECT) != 0;
}

pub fn flushTLB() void {
    writeCR3(readCR3());
}

pub fn flushAllTLB() void {
    const current = readCR4();
    if ((current & constants.CR4_PAGE_GLOBAL_ENABLE) != 0) {
        writeCR4(current & ~constants.CR4_PAGE_GLOBAL_ENABLE);
        writeCR4(current);
    } else {
        flushTLB();
    }
}

pub fn invalidatePage(virtual_address: u64) void {
    asm volatile (strings.INVALIDATE_PAGE
        :
        : [address] "r" (virtual_address),
        : .{ .memory = true });
}
