//! Trusted Bootstrap ELF Construction

const common = @import("common");
const elf = @import("shared").elf;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const layout = @import("mirai").bootstrap.image.layout;
const memory = @import("mirai").bootstrap.image.memory;
const pmm = @import("mirai").pmm;
const strings = @import("mirai").bootstrap.strings.image;
const thread = @import("mirai").thread;
const types = @import("mirai").bootstrap.types.image;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
const Kata = kata.types.kata.Kata;

pub fn prepare(launcher: *const Kata, bytes: []const u8, options: types.Options) ImageError!types.Prepared {
    const flags = guard.acquire();
    defer guard.release(flags);
    const top = try layout.stack(options);
    const plan = try elf.validate.image.parse(bytes, .{
        .MinimumAddress = common.constants.memory.sizes.PAGE_SIZE,
        .MaximumAddress = common.constants.memory.layout.USER_SPACE_END,
        .MaximumPages = pmm.state.getState().TotalPages - options.StackPages,
    });
    try layout.separate(&plan, options, top);
    const owner = try kata.create.createFor(launcher);
    errdefer kata.destroy.destroy(owner) catch @panic(strings.ROLLBACK_FAILED);
    try memory.allocateImage(owner, &plan);
    try memory.copyImage(owner, &plan, bytes);
    try memory.allocateStack(owner, options);
    try memory.finalizeImage(owner, &plan);
    try memory.finalizeStack(owner, options);
    const target = try thread.user.create(owner, plan.Entry, options.StackBase, options.StackPages * common.constants.memory.sizes.PAGE_SIZE, options.Argument);
    return .{ .ID = owner.ID, .Owner = owner, .Thread = target, .ThreadGeneration = thread.state.generation(target).? };
}
