//! Build Graph Assembly

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const catalog = @import("../persona/catalog.zig");
const disk = @import("../disk/disk.zig");
const kernel = @import("../kernel/kernel.zig");
const modules = @import("../modules/modules.zig");
const native = @import("../persona/native.zig");
const paths = @import("../strings/paths.zig");
const preview = @import("../preview/preview.zig");
const steps = @import("../steps/steps.zig");
const tests = @import("../tests/tests.zig");

pub fn build(builder: *std.Build) void {
    const module_set = modules.create.create(builder);
    native.exportSdk(builder, module_set.PersonaStartup);
    const bootloader_artifact = bootloader.compile.artifact(builder, module_set, false);
    const disk_artifact = disk.compile.artifact(builder, module_set);
    const kernel_artifact = kernel.compile.artifact(builder, module_set, null);
    const personas = catalog.build(builder, module_set);
    const outputs = catalog.outputs(builder, &personas, &.{
        .{ .Path = paths.HIKARI_OUTPUT, .File = bootloader_artifact.getEmittedBin() },
        .{ .Path = paths.MIRAI_OUTPUT, .File = kernel_artifact.getEmittedBin() },
    });
    _ = preview.compile.add(builder, module_set);
    steps.aggregate.add(builder, bootloader.compile.install(builder, bootloader_artifact), kernel.compile.install(builder, kernel_artifact), disk.compile.install(builder, disk_artifact), catalog.install(builder, &personas));
    builder.default_step.dependOn(steps.manifest.install(builder, outputs));
    tests.compile.add(builder, module_set, bootloader_artifact, disk_artifact, outputs, &personas);
}
