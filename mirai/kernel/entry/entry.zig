//! Kernel Entry

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const cpu = @import("asm").cpu;
const early = @import("mirai").boot.early;
const halt = @import("asm").cpu.halt;
const print = @import("mirai").boot.sequence.print;
const regions = @import("mirai").boot.regions;
const sequence = @import("mirai").boot.sequence;
const splash = @import("mirai").boot.splash;
const strings = @import("mirai").boot.strings.sequence.messages;
const types = @import("mirai").boot.types;

const BootInfo = types.sequence.info.BootInfo;
const BootParams = boot.types.params.BootParams;
const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub export fn mirai_entry(boot_params: *const BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (!early.setup.initialize()) halt.haltLoop();
    main(boot_params);
}

pub fn main(boot_params: *const BootParams) noreturn {
    const info = snapshot(boot_params) orelse {
        print.fail(strings.INVALID_BOOT_INFO);
        halt.haltLoop();
    };
    sequence.state.setBootInfo(&info);
    var framebuffer = boot_params.Framebuffer;
    framebuffer.Base = info.FramebufferAddress;
    _ = splash.adopt(framebuffer, boot_params.Splash);
    sequence.run.execute(sequence.state.getBootInfo().?);
}

fn snapshot(params: *const BootParams) ?BootInfo {
    const physical_bits = cpu.cpuid.physicalAddressBits() orelse return null;
    const coverage = @min(layout.PHYSMAP_MAX_SIZE, @as(u64, 1) << @as(u6, @intCast(physical_bits)));
    const params_address = @intFromPtr(params);
    if (params_address < layout.PHYSMAP_BASE or params_address % @alignOf(BootParams) != 0) return null;
    const params_offset = params_address - layout.PHYSMAP_BASE;
    if (params_offset >= coverage or @sizeOf(BootParams) > coverage - params_offset or !params.isValid()) return null;
    const kernel = params.Kernel;
    if (kernel.PhysmapBase != layout.PHYSMAP_BASE or kernel.PhysmapSize != coverage or
        kernel.PhysicalBase == 0 or kernel.Size == 0 or kernel.PhysicalBase >= coverage or kernel.Size > coverage - kernel.PhysicalBase or
        ((kernel.PhysicalBase | kernel.VirtualBase | kernel.Size) & sizes.PAGE_MASK) != 0 or
        kernel.VirtualBase < layout.KERNEL_BASE or kernel.Size > std.math.maxInt(u64) - kernel.VirtualBase or
        kernel.EntryPoint < kernel.VirtualBase or kernel.EntryPoint - kernel.VirtualBase >= kernel.Size or
        kernel.PML4Address == 0 or (kernel.PML4Address & sizes.PAGE_MASK) != 0 or kernel.PML4Address > coverage - sizes.PAGE_SIZE or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != kernel.PML4Address or
        kernel.StackTop <= layout.PHYSMAP_BASE or kernel.StackSize == 0 or
        ((kernel.StackTop | kernel.StackSize) & sizes.PAGE_MASK) != 0)
    {
        return null;
    }
    const stack_end = kernel.StackTop - layout.PHYSMAP_BASE;
    if (stack_end > coverage or kernel.StackSize >= stack_end) return null;
    const current_stack = cpu.state.readStackPointer();
    if (current_stack < kernel.StackTop - kernel.StackSize or current_stack >= kernel.StackTop) return null;
    const framebuffer = params.Framebuffer;
    const row_bytes = @as(u64, framebuffer.Stride) * @sizeOf(u32);
    if (framebuffer.Base == 0 or framebuffer.Size == 0 or framebuffer.Base >= coverage or framebuffer.Size > coverage - framebuffer.Base or
        framebuffer.Width == 0 or framebuffer.Height == 0 or framebuffer.Stride < framebuffer.Width or
        row_bytes == 0 or row_bytes > std.math.maxInt(u32) or framebuffer.Height > framebuffer.Size / row_bytes or
        (framebuffer.PixelFormat != .RGB and framebuffer.PixelFormat != .BGR))
    {
        return null;
    }
    const memory_regions = regions.convert.convert(params.MemoryMap, coverage) orelse return null;
    const rsdp = params.ACPI.RSDPAddress;
    if (rsdp >= coverage) return null;
    return .{
        .MemoryMap = memory_regions.ptr,
        .MemoryMapCount = memory_regions.len,
        .FramebufferAddress = layout.PHYSMAP_BASE + framebuffer.Base,
        .FramebufferPhysicalAddress = framebuffer.Base,
        .FramebufferSize = framebuffer.Size,
        .FramebufferWidth = framebuffer.Width,
        .FramebufferHeight = framebuffer.Height,
        .FramebufferPitch = @intCast(row_bytes),
        .FramebufferBPP = @bitSizeOf(u32),
        .KernelPhysicalBase = kernel.PhysicalBase,
        .KernelPhysicalEnd = kernel.PhysicalBase + kernel.Size,
        .KernelVirtualBase = kernel.VirtualBase,
        .PML4Physical = kernel.PML4Address,
        .LoaderPML4Physical = kernel.PML4Address,
        .PhysmapBase = kernel.PhysmapBase,
        .PhysmapSize = coverage,
        .RSDPAddress = if (rsdp == 0) 0 else layout.PHYSMAP_BASE + rsdp,
        .BootStackTop = kernel.StackTop,
        .BootStackSize = kernel.StackSize,
    };
}
