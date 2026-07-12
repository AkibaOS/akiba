//! Build Orchestration

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const disk = @import("../disk/disk.zig");
const kernel = @import("../kernel/kernel.zig");
const modules = @import("../modules/modules.zig");
const steps = @import("../steps/steps.zig");

pub fn build(builder: *std.Build) void {
    const module_set = modules.create(builder);
    const bootloader_step = bootloader.add(builder, module_set);
    const kernel_step = kernel.add(builder, module_set);
    const disk_step = disk.add(builder, module_set);
    steps.add(builder, bootloader_step, kernel_step, disk_step);
}
