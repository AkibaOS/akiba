//! Build Graph Assembly

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const disk = @import("../disk/disk.zig");
const kernel = @import("../kernel/kernel.zig");
const modules = @import("../modules/modules.zig");
const preview = @import("../preview/preview.zig");
const steps = @import("../steps/steps.zig");

pub fn build(builder: *std.Build) void {
    const module_set = modules.create.create(builder);
    const bootloader_step = bootloader.compile.add(builder, module_set);
    const kernel_step = kernel.compile.add(builder, module_set);
    const disk_step = disk.compile.add(builder, module_set);
    _ = preview.compile.add(builder, module_set);
    steps.aggregate.add(builder, bootloader_step, kernel_step, disk_step);
}
