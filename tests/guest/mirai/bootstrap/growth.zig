//! Large ELF Image And Explicit Persona Stack Commitment

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const fixture = @import("tests").fixtures.bytes.elf;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").fixtures.constants.elf;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.elf;
const pmm = @import("mirai").pmm;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const IMAGE = blk: {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(2) + 40, inputs.COMMITTED_BSS_PAGES * inputs.PAGE_BYTES);
    break :blk bytes;
};

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const search = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = search;
    const warm = try prepare();
    try bootstrap.image.abort.abort(warm);
    pmm.state.getState().SearchStart = search;
    const before = pmm.state.getStatistics();
    const image = try prepare();
    var live = true;
    defer if (live) bootstrap.image.abort.abort(image) catch |failure| verify.failure(failure);
    const root = image.Owner.AddressSpace.?;
    verify.require(image.Owner.State == .Born and image.Thread.Mode == .Persona and
        root.ResidentPages == 2 + inputs.COMMITTED_BSS_PAGES + inputs.COMMITTED_STACK_PAGES and
        image.Thread.User.StackTop == inputs.STACK_ADDRESS + inputs.COMMITTED_STACK_PAGES * inputs.PAGE_BYTES, labels.GROWTH);
    var bytes: [inputs.HEADER_BYTES]u8 = undefined;
    const last = inputs.CODE_ADDRESS + (1 + inputs.COMMITTED_BSS_PAGES) * inputs.PAGE_BYTES;
    try user.copy.transfer.read(image.Owner, &bytes, last);
    verify.require(std.mem.allEqual(u8, &bytes, 0) and kagami.extract.isWritable(root, last) and
        !kagami.extract.isExecutable(root, last) and !kagami.extract.isMapped(root, inputs.STACK_ADDRESS - inputs.PAGE_BYTES) and
        !kagami.extract.isMapped(root, image.Thread.User.StackTop) and
        kagami.extract.isWritable(root, image.Thread.User.StackTop - inputs.PAGE_BYTES) and
        !kagami.extract.isExecutable(root, image.Thread.User.StackTop - inputs.PAGE_BYTES), labels.GROWTH_CONTENTS);
    try bootstrap.image.abort.abort(image);
    live = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.GROWTH_RELEASE);
}

fn prepare() !bootstrap.types.image.preparation.Prepared {
    return bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, &IMAGE, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = inputs.COMMITTED_STACK_PAGES,
    });
}
