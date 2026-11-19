//! Bootstrap Image Transaction Errors

const common = @import("common");
const kata = @import("mirai").kata.errors.ownership;
const sensei = @import("mirai").sensei.errors.scheduling;
const shared = @import("shared").elf.errors.image;
const thread = @import("mirai").thread.errors.ownership;
const user = @import("mirai").user.errors.memory;

pub const ImageError = shared.ImageError || user.UserError || kata.OwnershipError || thread.OwnershipError ||
    common.errors.memory.allocation.AllocationError || error{
    InvalidStack,
    StackOverlap,
    InvalidImage,
    InUse,
};

pub const LaunchError = ImageError || sensei.SchedulingError;
