//! Build Graph Assembly

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const disk = @import("../disk/disk.zig");
const drivers = @import("../drivers/drivers.zig");
const kernel = @import("../kernel/kernel.zig");
const modules = @import("../modules/modules.zig");
const preview = @import("../preview/preview.zig");
const pulse = @import("../pulse/pulse.zig");
const steps = @import("../steps/steps.zig");
const tests = @import("../tests/tests.zig");
const weaver = @import("../weaver/weaver.zig");

pub fn build(builder: *std.Build) void {
    const module_set = modules.create.create(builder);
    const bootloader_artifact = bootloader.compile.artifact(builder, module_set, false);
    const disk_artifact = disk.compile.artifact(builder, module_set);
    const bootloader_step = bootloader.compile.install(builder, bootloader_artifact);
    const kernel_artifact = kernel.compile.artifact(builder, module_set, null);
    const kernel_step = kernel.compile.install(builder, kernel_artifact);
    const disk_step = disk.compile.install(builder, disk_artifact);
    const weaver_artifact = weaver.compile.artifact(builder, module_set);
    const ahci_artifact = drivers.ahci.artifact(builder, module_set);
    const afs_artifact = drivers.afs.artifact(builder, module_set);
    const keyboard_artifact = drivers.keyboard.artifact(builder, module_set);
    const pulse_artifact = pulse.compile.artifact(builder, module_set, weaver_artifact, ahci_artifact, afs_artifact);
    const pulse_step = pulse.compile.install(builder, pulse_artifact);
    pulse_step.dependOn(drivers.ahci.install(builder, ahci_artifact));
    pulse_step.dependOn(drivers.afs.install(builder, afs_artifact));
    pulse_step.dependOn(drivers.keyboard.install(builder, keyboard_artifact));
    _ = preview.compile.add(builder, module_set);
    steps.aggregate.add(builder, bootloader_step, kernel_step, disk_step, pulse_step);
    tests.compile.add(builder, module_set, bootloader_artifact, kernel_artifact, disk_artifact, pulse_artifact, ahci_artifact, afs_artifact, keyboard_artifact);
}
