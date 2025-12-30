//! Invocation Handler - Entry point for Layer 3 programs calling kernel
//! Handles the Akiba Invocation Table

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const serial = @import("../drivers/serial.zig");
const syscall = @import("syscall.zig");

const attach = @import("attach.zig");
const exit = @import("exit.zig");
const mark = @import("mark.zig");
const seal = @import("seal.zig");
const spawn = @import("spawn.zig");
const view = @import("view.zig");
const wait = @import("wait.zig");
const yield = @import("yield.zig");

pub fn init(fs: *afs.AFS(ahci.BlockDevice)) void {
    serial.print("\n=== Invocation Handler ===\n");

    // Set AFS instance for all invocations that need it
    exit.set_afs_instance(fs);
    attach.set_afs_instance(fs);
    seal.set_afs_instance(fs);
    spawn.set_afs_instance(fs);

    serial.print("Akiba Invocation Table initialized\n");

    syscall.init();
}

pub fn handle_invocation(context: *InvocationContext) void {
    const invocation_num = context.rax;

    switch (invocation_num) {
        0x01 => exit.invoke(context),
        0x02 => attach.invoke(context),
        0x03 => seal.invoke(context),
        0x04 => view.invoke(context),
        0x05 => mark.invoke(context),
        0x06 => spawn.invoke(context),
        0x07 => wait.invoke(context),
        0x08 => yield.invoke(context),
        else => {
            serial.print("Unknown invocation: ");
            serial.print_hex(invocation_num);
            serial.print("\n");
            context.rax = @as(u64, @bitCast(@as(i64, -1)));
        },
    }
}

pub const InvocationContext = struct {
    rax: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    r10: u64,
    r8: u64,
    r9: u64,
    rbx: u64,
    rcx: u64,
    rbp: u64,
    rsp: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rip: u64,
    rflags: u64,
    cs: u64,
    ss: u64,
};
