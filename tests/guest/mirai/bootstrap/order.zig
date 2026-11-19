//! Reversed Shared Page BSS And Initialized Image Construction

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const fixture = @import("tests").fixtures.bytes.elf;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.elf;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.elf;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const IMAGE = blk: {
    var bytes = fixture.create();
    fixture.share(&bytes, false);
    fixture.write64(&bytes, fixture.program(1) + 32, 0);
    var temporary: [inputs.PROGRAM_BYTES]u8 = undefined;
    @memcpy(&temporary, bytes[fixture.program(0)..][0..inputs.PROGRAM_BYTES]);
    @memcpy(bytes[fixture.program(0)..][0..inputs.PROGRAM_BYTES], bytes[fixture.program(1)..][0..inputs.PROGRAM_BYTES]);
    @memcpy(bytes[fixture.program(1)..][0..inputs.PROGRAM_BYTES], &temporary);
    break :blk bytes;
};

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const image = try bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, &IMAGE, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 2,
    });
    defer bootstrap.image.abort.abort(image) catch |failure| verify.failure(failure);
    var initialized: [32]u8 = undefined;
    var bss: [32]u8 = undefined;
    try user.copy.transfer.read(image.Owner, &initialized, inputs.CODE_ADDRESS);
    try user.copy.transfer.read(image.Owner, &bss, inputs.CODE_ADDRESS + 0x100);
    const root = image.Owner.AddressSpace.?;
    verify.require(std.mem.allEqual(u8, &initialized, 0x90) and std.mem.allEqual(u8, &bss, 0) and
        root.ResidentPages == 5 and kagami.extract.isExecutable(root, inputs.CODE_ADDRESS) and
        !kagami.extract.isWritable(root, inputs.CODE_ADDRESS), labels.SHARED_BSS);
}
