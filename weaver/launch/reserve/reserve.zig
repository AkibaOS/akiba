//! Check Guarded Stack And Startup Record Reservations

const std = @import("std");

const elf = @import("shared").elf;
const launch = @import("weaver").launch;
const sizes = @import("common").constants.memory.sizes;
const startup = @import("shared").launch.startup;

const Options = launch.types.request.Options;
const RequestError = launch.errors.request.RequestError;
const Spans = launch.types.request.Spans;

pub fn reserve(options: Options) RequestError!Spans {
    try elf.validate.load.validatePolicy(options.Policy);
    const minimum = options.Policy.MinimumAddress;
    const limit = options.Policy.MaximumAddress + 1;
    if (options.StackPages == 0 or options.StackBase < sizes.PAGE_SIZE or options.StackBase & sizes.PAGE_MASK != 0)
        return error.InvalidStack;
    const lower_guard = options.StackBase - sizes.PAGE_SIZE;
    if (lower_guard < minimum) return error.InvalidStack;
    const length = std.math.mul(u64, options.StackPages, sizes.PAGE_SIZE) catch return error.InvalidStack;
    const stack_end = std.math.add(u64, options.StackBase, length) catch return error.InvalidStack;
    const end = std.math.add(u64, stack_end, sizes.PAGE_SIZE) catch return error.InvalidStack;
    if (end > limit) return error.InvalidStack;
    const base = options.StartupBase;
    if (base < minimum or base >= limit or base & sizes.PAGE_MASK != 0) return error.InvalidStartup;
    const extent = try startup.size(options.Identity.len, options.Parameters.len, limit - base);
    return .{
        .GuardedStack = .{ .Start = lower_guard, .End = end },
        .Startup = .{ .Start = base, .End = base + extent },
        .StackLength = length,
    };
}
