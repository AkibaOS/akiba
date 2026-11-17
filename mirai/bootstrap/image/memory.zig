//! Owned Bootstrap Image Population And Finalization

const common = @import("common");
const format = @import("shared").elf.constants.format;
const pages = @import("shared").elf.validate.pages;
const types = @import("mirai").bootstrap.types.image;
const user = @import("mirai").user;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
const Kata = @import("mirai").kata.types.kata.Kata;
const Plan = @import("shared").elf.types.image.Plan;
const sizes = common.constants.memory.sizes;

pub fn allocateImage(owner: *Kata, plan: *const Plan) ImageError!void {
    for (plan.Segments[0..plan.Count], 0..) |segment, index| {
        var address = pages.start(segment);
        while (address < pages.end(segment)) : (address += sizes.PAGE_SIZE) {
            if (pages.isFirst(plan, index, address)) try user.memory.allocate.allocate(owner, address);
        }
    }
}

pub fn copyImage(owner: *Kata, plan: *const Plan, bytes: []const u8) ImageError!void {
    for (plan.Segments[0..plan.Count]) |segment| {
        var offset: u64 = 0;
        while (offset < segment.UnitSize) {
            const length: usize = @intCast(@min(segment.UnitSize - offset, user.constants.limits.MAX_COPY_BYTES));
            const source: usize = @intCast(segment.Offset + offset);
            try user.memory.load.load(owner, segment.VirtualAddress + offset, bytes[source..][0..length]);
            offset += length;
        }
    }
}

pub fn allocateStack(owner: *Kata, options: types.Options) ImageError!void {
    var index: u64 = 0;
    while (index < options.StackPages) : (index += 1) {
        try user.memory.allocate.allocate(owner, options.StackBase + index * sizes.PAGE_SIZE);
    }
}

pub fn finalizeImage(owner: *Kata, plan: *const Plan) ImageError!void {
    for (plan.Segments[0..plan.Count], 0..) |segment, index| {
        var address = pages.start(segment);
        while (address < pages.end(segment)) : (address += sizes.PAGE_SIZE) {
            if (!pages.isFirst(plan, index, address)) continue;
            const flags = pages.flags(plan, address);
            const protection: user.types.protection.Protection = if ((flags & format.SEGMENT_FLAG_EXECUTE) != 0) .ReadExecute else if ((flags & format.SEGMENT_FLAG_WRITE) != 0) .ReadWrite else .ReadOnly;
            try user.memory.finalize.finalize(owner, address, protection);
        }
    }
}

pub fn finalizeStack(owner: *Kata, options: types.Options) ImageError!void {
    var index: u64 = 0;
    while (index < options.StackPages) : (index += 1) {
        try user.memory.finalize.finalize(owner, options.StackBase + index * sizes.PAGE_SIZE, .ReadWrite);
    }
}
