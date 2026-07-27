//! Kernel Entry

const boot = @import("shared").boot;

const halt = @import("asm").cpu.halt;

const constants = @import("../constants/constants.zig");
const framebuffer = @import("../../drivers/framebuffer/framebuffer.zig");
const regions = @import("../../boot/regions/regions.zig");
const sequence = @import("../../boot/sequence/sequence.zig");
const types = @import("../../boot/types/types.zig");

const colors = constants.colors;

const BootInfo = types.sequence.info.BootInfo;
const BootParams = boot.types.params.BootParams;

pub export fn mirai_entry(boot_params: *BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    main(boot_params);
}

pub fn main(boot_params: *BootParams) noreturn {
    const framebuffer_info = boot_params.Framebuffer;
    _ = framebuffer.init.initialize(
        framebuffer_info.Base,
        framebuffer_info.Width,
        framebuffer_info.Height,
        framebuffer_info.Stride,
    );

    if (!boot_params.isValid()) {
        framebuffer.draw.fill(switch (framebuffer_info.PixelFormat) {
            .BGR => colors.ERROR_BGR,
            else => colors.ERROR_RGB,
        });
        halt.haltLoop();
    }

    const memory_regions = regions.convert.convert(boot_params.MemoryMap);

    const boot_info = BootInfo{
        .MemoryMap = memory_regions.ptr,
        .MemoryMapCount = memory_regions.len,
        .FramebufferAddress = framebuffer_info.Base,
        .FramebufferWidth = framebuffer_info.Width,
        .FramebufferHeight = framebuffer_info.Height,
        .FramebufferPitch = framebuffer_info.Stride * @sizeOf(u32),
        .FramebufferBPP = @bitSizeOf(u32),
        .KernelPhysicalBase = boot_params.Kernel.PhysicalBase,
        .KernelPhysicalEnd = boot_params.Kernel.PhysicalBase + boot_params.Kernel.Size,
        .KernelVirtualBase = boot_params.Kernel.VirtualBase,
        .PML4Physical = boot_params.Kernel.PML4Address,
        .RSDPAddress = boot_params.ACPI.RSDPAddress,
        .BootStackTop = boot_params.Kernel.StackTop,
    };

    if (!sequence.run.execute(&boot_info)) {
        sequence.run.haltOnFailure();
    }

    halt.haltLoop();
}
