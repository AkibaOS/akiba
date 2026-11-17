//! Bootstrap Stack Geometry And Image Separation

const common = @import("common");
const types = @import("mirai").bootstrap.types.image;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
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
