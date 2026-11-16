//! Build Graph Assembly

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const checks = @import("../checks/checks.zig");
const disk = @import("../disk/disk.zig");
const kernel = @import("../kernel/kernel.zig");
const modules = @import("../modules/modules.zig");
const preview = @import("../preview/preview.zig");
const steps = @import("../steps/steps.zig");

pub fn build(builder: *std.Build) void {
    const module_set = modules.create.create(builder);
    const bootloader_artifact = bootloader.compile.artifact(builder, module_set);
    const disk_artifact = disk.compile.artifact(builder, module_set);
    const bootloader_step = bootloader.compile.install(builder, bootloader_artifact);
    const kernel_step = kernel.compile.add(builder, module_set);
    const disk_step = disk.compile.install(builder, disk_artifact);
    _ = preview.compile.add(builder, module_set);
    steps.aggregate.add(builder, bootloader_step, kernel_step, disk_step);
    checks.compile.add(builder, module_set, bootloader_artifact, disk_artifact);
}
