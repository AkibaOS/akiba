//! Trusted Bootstrap ELF Construction

const allocator = @import("mirai").memory.allocator.native;
const common = @import("common");
const elf = @import("shared").elf;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const layout = @import("mirai").bootstrap.image.layout;
const memory = @import("mirai").bootstrap.image.memory;
const startup = @import("mirai").bootstrap.image.startup;
const strings = @import("mirai").bootstrap.strings.image.rollback;
const thread = @import("mirai").thread;
const types = @import("mirai").bootstrap.types.image.preparation;

const ImageError = @import("mirai").bootstrap.errors.image.preparation.ImageError;
const Kata = kata.types.kata.Kata;

pub fn prepare(launcher: *const Kata, bytes: []const u8, options: types.Options) ImageError!types.Prepared {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (options.Startup != null and options.Argument != 0) return ImageError.InvalidStartup;
    const top = try layout.stack(options);
    var plan = try elf.validate.image.parse(allocator.get(), bytes, .{
        .MinimumAddress = common.constants.memory.sizes.PAGE_SIZE,
        .MaximumAddress = common.constants.memory.layout.USER_SPACE_END,
        .MaximumPages = common.constants.memory.layout.USER_SPACE_END / common.constants.memory.sizes.PAGE_SIZE - options.StackPages,
    });
    defer plan.deinit();
    try layout.separate(&plan, options, top);
    const span = if (options.Startup) |source| try layout.placeStartup(&plan, options, top, try startup.pageBytes(source)) else null;
    const owner = try kata.create.createFor(launcher);
    errdefer kata.destroy.destroy(owner) catch @panic(strings.ROLLBACK_FAILED);
    try memory.allocateImage(owner, &plan);
    try memory.copyImage(owner, &plan, bytes);
    try memory.allocateStack(owner, options);
    try memory.finalizeImage(owner, &plan);
    try memory.finalizeStack(owner, options);
    const argument = if (span) |placement| handoff: {
        try startup.install(owner, placement, options.Startup.?);
        break :handoff placement.Start;
    } else options.Argument;
    const target = try thread.user.create(owner, plan.Entry, options.StackBase, options.StackPages * common.constants.memory.sizes.PAGE_SIZE, argument);
    return .{ .ID = owner.ID, .Owner = owner, .Thread = target, .ThreadGeneration = thread.state.generation(target).? };
}
