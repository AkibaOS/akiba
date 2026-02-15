//! Invocation Handler - Entry point for Kata programs calling Mirai

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const invocations = @import("../common/constants/invocations.zig");
const result = @import("../utils/types/result.zig");
const syscall = @import("syscall.zig");

const attach = @import("io/attach.zig");
const getkeychar = @import("io/getkeychar.zig");
const mark = @import("io/mark.zig");
const seal = @import("io/seal.zig");
const view = @import("io/view.zig");
const wipe = @import("io/wipe.zig");

const getlocation = @import("fs/getlocation.zig");
const setlocation = @import("fs/setlocation.zig");
const viewstack = @import("fs/viewstack.zig");

const exit = @import("kata/exit.zig");
const postman = @import("kata/postman.zig");
const spawn = @import("kata/spawn.zig");
const wait = @import("kata/wait.zig");
const yield = @import("kata/yield.zig");

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

pub fn init(fs: *afs.AFS(ahci.BlockDevice)) void {
    exit.set_afs_instance(fs);
    attach.set_afs_instance(fs);
    seal.set_afs_instance(fs);
    spawn.set_afs_instance(fs);
    viewstack.set_afs_instance(fs);
    setlocation.set_afs_instance(fs);

    syscall.init();
}

pub fn handle(ctx: *InvocationContext) void {
    switch (ctx.rax) {
        invocations.EXIT => exit.invoke(ctx),
        invocations.ATTACH => attach.invoke(ctx),
        invocations.SEAL => seal.invoke(ctx),
        invocations.VIEW => view.invoke(ctx),
        invocations.MARK => mark.invoke(ctx),
        invocations.SPAWN => spawn.invoke(ctx),
        invocations.WAIT => wait.invoke(ctx),
        invocations.YIELD => yield.invoke(ctx),
        invocations.GETKEYCHAR => getkeychar.invoke(ctx),
        invocations.VIEWSTACK => viewstack.invoke(ctx),
        invocations.GETLOCATION => getlocation.invoke(ctx),
        invocations.SETLOCATION => setlocation.invoke(ctx),
        invocations.POSTMAN => postman.invoke(ctx),
        invocations.WIPE => wipe.invoke(ctx),
        else => result.set_error(ctx),
    }
}
