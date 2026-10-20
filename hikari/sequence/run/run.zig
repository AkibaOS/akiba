//! Hikari Boot Sequence Runner

const std = @import("std");

const acpi = @import("hikari").sequence.acpi;
const assembly = @import("hikari").assembly;
const boot = @import("shared").boot;
const common = @import("common");
const console = @import("hikari").sequence.console;
const constants = @import("hikari").sequence.constants;
const control = @import("asm").cpu.control;
const efi = @import("hikari").efi;
const fpu = @import("asm").cpu.fpu;
const fs = @import("hikari").fs;
const graphics = @import("hikari").sequence.graphics;
const handoff = @import("hikari").sequence.handoff;
const loader = @import("hikari").loader;
const math = @import("utils").math;
const msr = @import("asm").cpu.msr;
const paging = @import("hikari").paging;
const partition = @import("hikari").sequence.partition;
const processor = @import("asm").cpu.constants;
const splash = @import("hikari").sequence.splash;
const strings = @import("hikari").sequence.strings;

const layout = common.constants.memory.layout;
const messages = strings.messages;
const paths = strings.paths;
const sizes = common.constants.memory.sizes;
const status = efi.constants.status;

pub fn run(image_handle: efi.types.base.Handle, system_table: *efi.types.services.system.SystemTable) efi.types.base.Status {
    const boot_services = system_table.BootServices;
    const console_output = system_table.ConsoleOutput;
    _ = console_output.ClearScreen(console_output);
    const gop = graphics.getGraphicsOutput(boot_services) orelse {
        console.print(console_output, messages.ERROR_DISPLAY);
        return status.UNSUPPORTED;
    };
    const mode = gop.Mode;
    const info = mode.Info;
    const row_bytes = @as(u64, info.PixelsPerScanLine) * @sizeOf(u32);
    if (mode.FramebufferBase == 0 or mode.FramebufferSize == 0 or info.HorizontalResolution == 0 or
        mode.FramebufferSize > std.math.maxInt(u64) - mode.FramebufferBase or
        info.VerticalResolution == 0 or info.PixelsPerScanLine < info.HorizontalResolution or row_bytes == 0 or
        info.VerticalResolution > mode.FramebufferSize / row_bytes)
    {
        console.print(console_output, messages.ERROR_DISPLAY);
        return status.UNSUPPORTED;
    }
    _ = splash.initialize(gop, console_output);
    splash.report(messages.INITIALIZING_DISPLAY);
    splash.report(messages.LOCATING_FILE_SYSTEM);
    const afs_partition = partition.findAfsPartition(boot_services) orelse {
        splash.fail(messages.ERROR_FILE_SYSTEM_NOT_FOUND);
        return status.NOT_FOUND;
    };
    splash.report(messages.INITIALIZING_FILE_SYSTEM);
    var afs_reader = fs.types.afs.reader.Reader.initialize(afs_partition.BlockIO, boot_services, afs_partition.StartLBA, afs_partition.EndLBA) catch {
        splash.fail(messages.ERROR_FILE_SYSTEM);
        return status.DEVICE_ERROR;
    };
    defer afs_reader.deinitialize();
    splash.report(messages.LOADING_KERNEL);
    const kernel_unit = afs_reader.openLocation(paths.KERNEL_LOCATION) catch {
        splash.fail(messages.ERROR_KERNEL_NOT_FOUND);
        return status.NOT_FOUND;
    };
    const kernel_size = kernel_unit.DataChannel.LogicalSize;
    if (kernel_size < loader.constants.elf.ELF64_HEADER_SIZE or kernel_size > loader.constants.kernel.MAX_UNIT_SIZE) {
        splash.fail(messages.ERROR_KERNEL_DAMAGED);
        return status.INVALID_PARAMETER;
    }
    const kernel_data = afs_reader.readUnitToAllocated(&kernel_unit, loader.constants.kernel.MAX_UNIT_SIZE) catch {
        splash.fail(messages.ERROR_KERNEL_READ);
        return status.DEVICE_ERROR;
    };
    var kernel_buffer_live = true;
    defer if (kernel_buffer_live) {
        _ = boot_services.FreePool(@alignCast(kernel_data.Buffer));
    };
    afs_reader.deinitialize();
    splash.report(messages.VERIFYING_KERNEL);
    const kernel_bytes = kernel_data.Buffer[0..kernel_data.Size];
    _ = loader.elf.validation.validateImage(kernel_bytes) catch {
        splash.fail(messages.ERROR_KERNEL_DAMAGED);
        return status.INVALID_PARAMETER;
    };
    if (!msr.enableNoExecute() or !control.enableWriteProtect()) {
        splash.fail(messages.ERROR_MEMORY);
        return status.UNSUPPORTED;
    }
    splash.report(messages.PREPARING_MEMORY);
    var page_setup = paging.types.setup.PageTableSetup.initialize(boot_services) catch {
        splash.fail(messages.ERROR_MEMORY);
        return status.OUT_OF_RESOURCES;
    };
    defer page_setup.deinitialize();
    splash.report(messages.PREPARING_KERNEL);
    const loaded_image = loader.elf.loader.load(boot_services, page_setup.PhysmapLimit, kernel_bytes) catch {
        splash.fail(messages.ERROR_KERNEL_LOAD);
        return status.LOAD_ERROR;
    };
    defer _ = boot_services.FreePages(loaded_image.BaseAddress, @intCast(loaded_image.totalSize() / sizes.PAGE_SIZE));
    const release_buffer = boot_services.FreePool(@alignCast(kernel_data.Buffer));
    if (efi.status.isError(release_buffer)) return status.DEVICE_ERROR;
    kernel_buffer_live = false;

    page_setup.mapIdentity(0, constants.memory.IDENTITY_MAP_SIZE) catch {
        splash.fail(messages.ERROR_MEMORY);
        return status.OUT_OF_RESOURCES;
    };
    var image_protocol: ?*anyopaque = null;
    const image_status = boot_services.HandleProtocol(image_handle, &efi.constants.guids.LOADED_IMAGE_PROTOCOL, &image_protocol);
    if (efi.status.isError(image_status) or image_protocol == null) return status.LOAD_ERROR;
    const current_image: *const efi.types.protocols.image.LoadedImageProtocol = @ptrCast(@alignCast(image_protocol.?));
    if (current_image.ImageSize == 0) return status.LOAD_ERROR;
    page_setup.mapIdentity(@intFromPtr(current_image.ImageBase), current_image.ImageSize) catch return status.NO_MAPPING;
    page_setup.mapPhysmap() catch return status.OUT_OF_RESOURCES;
    if (mode.FramebufferBase >= page_setup.PhysmapSize or mode.FramebufferSize > page_setup.PhysmapSize - mode.FramebufferBase) return status.NO_MAPPING;
    const framebuffer_start = math.integer.alignDown(mode.FramebufferBase, sizes.LARGE_PAGE_SIZE);
    const framebuffer_end = math.integer.alignUp(mode.FramebufferBase + mode.FramebufferSize, sizes.LARGE_PAGE_SIZE);
    if (framebuffer_start < loaded_image.EndAddress and loaded_image.BaseAddress < framebuffer_end) return status.NO_MAPPING;
    page_setup.mapFramebuffer(mode.FramebufferBase, mode.FramebufferSize) catch return status.NO_MAPPING;
    for (loaded_image.Segments[0..loaded_image.SegmentCount]) |region| {
        page_setup.mapKernelSegment(
            region.VirtualAddress,
            region.PhysicalAddress,
            region.MemorySize,
            (region.Flags & loader.constants.elf.SEGMENT_FLAG_WRITE) != 0,
            (region.Flags & loader.constants.elf.SEGMENT_FLAG_EXECUTE) != 0,
        ) catch return status.NO_MAPPING;
    }
    page_setup.protectKernelAliases(loaded_image.BaseAddress, loaded_image.totalSize(), true) catch return status.NO_MAPPING;
    for (loaded_image.Segments[0..loaded_image.SegmentCount]) |region| {
        if ((region.Flags & loader.constants.elf.SEGMENT_FLAG_WRITE) == 0) {
            page_setup.protectKernelAliases(region.PhysicalAddress, region.MemorySize, false) catch return status.NO_MAPPING;
        }
    }

    splash.report(messages.RESERVING_KERNEL_MEMORY);
    var startup = handoff.initialize(boot_services, page_setup.PhysmapSize) catch {
        splash.fail(messages.ERROR_STARTUP);
        return status.OUT_OF_RESOURCES;
    };
    defer handoff.deinitialize(&startup);
    splash.report(messages.PREPARING_STARTUP);
    const boot_params = handoff.parameters(&startup);
    boot_params.Framebuffer = boot.types.framebuffer.FramebufferInfo{
        .Base = mode.FramebufferBase,
        .Size = mode.FramebufferSize,
        .Width = info.HorizontalResolution,
        .Height = info.VerticalResolution,
        .Stride = info.PixelsPerScanLine,
        .PixelFormat = switch (info.PixelFormat) {
            .RGB => .RGB,
            .BGR => .BGR,
            else => .Unknown,
        },
        .RedMaskSize = @bitSizeOf(u8),
        .RedMaskShift = 2 * @bitSizeOf(u8),
        .GreenMaskSize = @bitSizeOf(u8),
        .GreenMaskShift = @bitSizeOf(u8),
        .BlueMaskSize = @bitSizeOf(u8),
        .BlueMaskShift = 0,
        .Reserved = .{ 0, 0 },
    };
    boot_params.Kernel = .{
        .PhysicalBase = loaded_image.BaseAddress,
        .VirtualBase = loaded_image.VirtualBase,
        .Size = loaded_image.totalSize(),
        .EntryPoint = loaded_image.EntryPoint,
        .PML4Address = page_setup.getL4Address(),
        .PhysmapBase = layout.PHYSMAP_BASE,
        .PhysmapSize = page_setup.PhysmapSize,
        .StackTop = handoff.stackTop(&startup),
        .StackSize = startup.StackPages * sizes.PAGE_SIZE,
    };
    boot_params.ACPI = acpi.findACPI(system_table);
    splash.report(messages.SURVEYING_MEMORY);
    splash.report(messages.STARTING_AKIBA);
    boot_params.Splash = splash.getState().*;
    handoff.exit(&startup, image_handle) catch {
        if (splash.isReady()) splash.fail(messages.ERROR_MEMORY_SURVEY);
        return status.LOAD_ERROR;
    };
    const floating_control = processor.control;
    control.writeCR0((control.readCR0() | floating_control.CR0_MONITOR_COPROCESSOR | floating_control.CR0_NUMERIC_ERROR) &
        ~(floating_control.CR0_EMULATION | floating_control.CR0_TASK_SWITCHED));
    control.writeCR4((control.readCR4() | floating_control.CR4_OS_FXSAVE | floating_control.CR4_OS_XMM_EXCEPTION) & ~floating_control.CR4_OS_XSAVE);
    fpu.initializeFpu();
    const mxcsr = processor.fpu.DEFAULT_MXCSR;
    fpu.loadMXCSR(&mxcsr);
    assembly.jump.jumpToKernel(loaded_image.EntryPoint, handoff.stackTop(&startup), handoff.parameterAlias(&startup), page_setup.getL4Address());
}
