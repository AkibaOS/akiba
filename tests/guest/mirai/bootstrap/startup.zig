//! Validate Real Startup Placement With A Low Guarded Stack

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

const IMAGE_BYTES = fixture.create();

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const stack_base = 2 * inputs.PAGE_BYTES;
    const stack_pages = 2;
    const image = try bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, &IMAGE_BYTES, .{
        .StackBase = stack_base,
        .StackPages = stack_pages,
        .Startup = .{ .Identity = labels.STARTUP_IDENTITY, .Parameters = &.{} },
    });
    defer bootstrap.image.abort.abort(image) catch |failure| verify.failure(failure);
    const first_guard = stack_base - inputs.PAGE_BYTES;
    const last_guard = stack_base + stack_pages * inputs.PAGE_BYTES;
    const argument = image.Thread.User.Argument;
    const root = image.Owner.AddressSpace.?;
    var bytes: [inputs.STARTUP_HEADER_BYTES + labels.STARTUP_IDENTITY.len + 1]u8 = undefined;
    try user.copy.transfer.read(image.Owner, &bytes, argument);
    verify.require(argument >= last_guard + inputs.PAGE_BYTES and !kagami.extract.isMapped(root, first_guard) and
        !kagami.extract.isMapped(root, last_guard) and !kagami.extract.isWritable(root, argument) and
        !kagami.extract.isExecutable(root, argument) and kagami.extract.isExecutable(root, inputs.CODE_ADDRESS) and
        std.mem.readInt(u64, bytes[16..24], .little) == 0 and
        std.mem.eql(u8, bytes[inputs.STARTUP_HEADER_BYTES .. bytes.len - 1], labels.STARTUP_IDENTITY) and
        bytes[bytes.len - 1] == 0, labels.STARTUP_GUARDS);
}
