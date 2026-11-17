//! Bootstrap Stack Geometry And Image Separation

const common = @import("common");
const pages = @import("shared").elf.validate.pages;
const thread = @import("mirai").thread.constants.user;
const types = @import("mirai").bootstrap.types.image;
const user = @import("mirai").user.constants.limits;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
const Plan = @import("shared").elf.types.image.Plan;
const sizes = common.constants.memory.sizes;
const address = common.constants.memory.layout;

pub fn stack(options: types.Options) ImageError!u64 {
    if (options.StackBase < 2 * sizes.PAGE_SIZE or (options.StackBase & sizes.PAGE_MASK) != 0 or
        options.StackPages == 0 or options.StackPages > thread.MAX_STACK_PAGES or
        options.StackPages >= user.MAX_OWNED_PAGES or options.StackBase > address.USER_SPACE_END)
        return ImageError.InvalidStack;
    const bytes = options.StackPages * sizes.PAGE_SIZE;
    if (bytes > address.USER_SPACE_END - options.StackBase) return ImageError.InvalidStack;
    const top = options.StackBase + bytes;
    if (sizes.PAGE_SIZE > address.USER_SPACE_END - top + 1) return ImageError.InvalidStack;
    return top;
}

pub fn separate(plan: *const Plan, options: types.Options, top: u64) ImageError!void {
    const lower = options.StackBase - sizes.PAGE_SIZE;
    const upper = top + sizes.PAGE_SIZE;
    for (plan.Segments[0..plan.Count]) |segment| {
        if (pages.start(segment) < upper and lower < pages.end(segment)) return ImageError.StackOverlap;
    }
}
