//! Bootstrap Stack Geometry And Image Separation

const common = @import("common");
const types = @import("mirai").bootstrap.types.image.preparation;

const ImageError = @import("mirai").bootstrap.errors.image.preparation.ImageError;
const Plan = @import("shared").elf.types.image.Plan;
const sizes = common.constants.memory.sizes;
const address = common.constants.memory.layout;

pub fn stack(options: types.Options) ImageError!u64 {
    if (options.StackBase < 2 * sizes.PAGE_SIZE or (options.StackBase & sizes.PAGE_MASK) != 0 or
        options.StackPages == 0 or options.StackBase > address.USER_SPACE_END) return ImageError.InvalidStack;
    const remaining = address.USER_SPACE_END - options.StackBase;
    if (remaining < sizes.PAGE_MASK or options.StackPages > (remaining - sizes.PAGE_MASK) / sizes.PAGE_SIZE)
        return ImageError.InvalidStack;
    return options.StackBase + options.StackPages * sizes.PAGE_SIZE;
}

pub fn separate(plan: *const Plan, options: types.Options, top: u64) ImageError!void {
    const lower = options.StackBase - sizes.PAGE_SIZE;
    const upper = top + sizes.PAGE_SIZE;
    for (plan.Ranges) |range| {
        if (range.Start < upper and lower < range.End) return ImageError.StackOverlap;
    }
}

pub fn placeStartup(plan: *const Plan, options: types.Options, top: u64, length: u64) ImageError!types.StartupSpan {
    const lower = options.StackBase - sizes.PAGE_SIZE;
    const upper = top + sizes.PAGE_SIZE;
    var cursor = sizes.PAGE_SIZE;
    for (plan.Ranges) |range| {
        if (fit(cursor, range.Start, lower, upper, length)) |start| return .{ .Start = start, .End = start + length };
        cursor = @max(cursor, range.End);
    }
    const start = fit(cursor, address.USER_SPACE_END + 1, lower, upper, length) orelse return ImageError.NoStartupSpace;
    return .{ .Start = start, .End = start + length };
}

fn fit(start: u64, end: u64, stack_start: u64, stack_end: u64, length: u64) ?u64 {
    if (start > end or length > end - start) return null;
    if (start >= stack_end or start + length <= stack_start) return start;
    if (stack_end <= end and length <= end - stack_end) return stack_end;
    return null;
}
