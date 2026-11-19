//! Hikari Boot Sequence Runner

const std = @import("std");

const acpi = @import("hikari").sequence.acpi;
const assembly = @import("hikari").assembly;
const boot = @import("shared").boot;
const cleanup = @import("hikari").sequence.cleanup;
const common = @import("common");
const console = @import("hikari").sequence.console;
const constants = @import("hikari").sequence.constants;
const control = @import("asm").cpu.control;
const cpuid = @import("asm").cpu.cpuid;
const efi = @import("hikari").efi;
const elf = @import("shared").elf.constants.format;
const fpu = @import("asm").cpu.fpu;
const fs = @import("hikari").fs;
const graphics = @import("hikari").sequence.graphics;
const handoff = @import("hikari").sequence.handoff;
const interrupts = @import("asm").interrupts.flags;
const loader = @import("hikari").loader;
const math = @import("utils").math;
const msr = @import("asm").cpu.msr;
const options = @import("options");
const partition = @import("hikari").sequence.partition;
const processor = @import("asm").cpu.constants;
const splash = @import("hikari").sequence.splash;
const strings = @import("hikari").sequence.strings;
const types = @import("hikari").sequence.types;

const layout = common.constants.memory.layout;
const messages = strings.messages;
const paths = strings.paths;
const sizes = common.constants.memory.sizes;
const status = efi.constants.status;

pub fn run(image_handle: efi.types.base.Handle, system_table: *efi.types.services.system.SystemTable) efi.types.base.Status {
    var claims: types.cleanup.Claims = .{ .Paging = .{ .BootServices = system_table.BootServices } };
    const result = launch(image_handle, system_table, &claims);
    if (!cleanup.finish(&claims)) {
        const attempted = if (claims.Handoff) |state| state.ExitAttempted or state.Exited else false;
        if (!attempted) splash.fail(messages.ERROR_CLEANUP);
        interrupts.disableInterrupts();
        if (attempted and splash.isReady()) splash.fail(messages.ERROR_CLEANUP);
        assembly.halt.haltLoop();
    }
    return result;
}

fn launch(image_handle: efi.types.base.Handle, system_table: *efi.types.services.system.SystemTable, claims: *types.cleanup.Claims) efi.types.base.Status {
    const boot_services = system_table.BootServices;
    const console_output = system_table.ConsoleOutput;
    _ = console_output.ClearScreen(console_output);
    const gop = graphics.getGraphicsOutput(boot_services) orelse {
        console.print(console_output, messages.ERROR_DISPLAY);
        return status.UNSUPPORTED;
    };
    const mode = gop.Mode;
    const info = mode.Info;
    const framebuffer = boot.types.framebuffer.FramebufferInfo{
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
    if (!framebuffer.isValid()) {
        console.print(console_output, messages.ERROR_DISPLAY);
        return status.UNSUPPORTED;
    }
    _ = splash.initialize(framebuffer, console_output, !options.DIAGNOSTIC_LOADER);
    splash.report(messages.INITIALIZING_DISPLAY);
    splash.report(messages.LOCATING_FILE_SYSTEM);
    claims.Discovery = .{ .Parser = .{ .BootServices = boot_services } };
    const located = partition.findAfsPartition(&claims.Discovery.?) catch {
        splash.fail(messages.ERROR_CLEANUP);
        return status.DEVICE_ERROR;
    };
    claims.Discovery = null;
    const afs_partition = located orelse {
        splash.fail(messages.ERROR_FILE_SYSTEM_NOT_FOUND);
        return status.NOT_FOUND;
    };
    splash.report(messages.INITIALIZING_FILE_SYSTEM);
    claims.Reader = .{ .BootServices = boot_services };
    const afs_reader = &claims.Reader.?;
    afs_reader.initialize(afs_partition.Media, afs_partition.StartLBA, afs_partition.EndLBA) catch |failure| {
        splash.fail(if (failure == error.ReleaseFailed) messages.ERROR_CLEANUP else messages.ERROR_FILE_SYSTEM);
        return status.DEVICE_ERROR;
    };
    splash.report(messages.LOADING_KERNEL);
    const kernel_location = if (options.DIAGNOSTIC_LOADER) paths.DIAGNOSTIC_KERNEL_LOCATION else paths.KERNEL_LOCATION;
    const kernel_unit = afs_reader.openLocation(kernel_location) catch {
        splash.fail(messages.ERROR_KERNEL_NOT_FOUND);
        return status.NOT_FOUND;
    };
    const kernel_size = kernel_unit.DataChannel.LogicalSize;
    if (kernel_size < elf.HEADER_BYTES) {
        splash.fail(messages.ERROR_KERNEL_DAMAGED);
        return status.INVALID_PARAMETER;
    }
    const kernel_bytes = afs_reader.readUnitToAllocated(&kernel_unit, std.math.maxInt(usize), &claims.Source) catch {
        splash.fail(messages.ERROR_KERNEL_READ);
        return status.DEVICE_ERROR;
    };
    if (!cleanup.releaseReader(claims)) {
        splash.fail(messages.ERROR_CLEANUP);
        return status.DEVICE_ERROR;
    }
    splash.report(messages.VERIFYING_KERNEL);
    _ = loader.elf.validation.validateImage(kernel_bytes) catch {
        splash.fail(messages.ERROR_KERNEL_DAMAGED);
        return status.INVALID_PARAMETER;
    };
    if (!cpuid.supportsNoExecute()) {
        splash.fail(messages.ERROR_MEMORY);
        return status.UNSUPPORTED;
    }
    const firmware_efer = msr.read(processor.msr.EFER);
    const firmware_cr0 = control.readCR0();
    defer {
        const write_protect = processor.control.CR0_WRITE_PROTECT;
        const no_execute = processor.msr.EFER_NO_EXECUTE_ENABLE;
        control.writeCR0((control.readCR0() & ~write_protect) | (firmware_cr0 & write_protect));
        msr.write(processor.msr.EFER, (msr.read(processor.msr.EFER) & ~no_execute) | (firmware_efer & no_execute));
    }
    if (!msr.enableNoExecute() or !control.enableWriteProtect()) {
        splash.fail(messages.ERROR_MEMORY);
        return status.UNSUPPORTED;
    }
    splash.report(messages.PREPARING_MEMORY);
    const page_setup = &claims.Paging;
    page_setup.initialize() catch {
        splash.fail(messages.ERROR_MEMORY);
        return status.OUT_OF_RESOURCES;
    };
    splash.report(messages.PREPARING_KERNEL);
    const loaded_image = loader.elf.loader.load(boot_services, page_setup.PhysmapLimit, kernel_bytes, &claims.Image) catch {
        splash.fail(messages.ERROR_KERNEL_LOAD);
        return status.LOAD_ERROR;
    };
    if (!cleanup.releaseSource(claims)) return status.DEVICE_ERROR;

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
            (region.Flags & elf.SEGMENT_FLAG_WRITE) != 0,
            (region.Flags & elf.SEGMENT_FLAG_EXECUTE) != 0,
        ) catch return status.NO_MAPPING;
    }
    page_setup.protectKernelAliases(loaded_image.BaseAddress, loaded_image.totalSize(), true) catch return status.NO_MAPPING;
    for (loaded_image.Segments[0..loaded_image.SegmentCount]) |region| {
        if ((region.Flags & elf.SEGMENT_FLAG_WRITE) == 0) {
            page_setup.protectKernelAliases(region.PhysicalAddress, region.MemorySize, false) catch return status.NO_MAPPING;
        }
    }

    splash.report(messages.RESERVING_KERNEL_MEMORY);
    claims.Handoff = .{ .BootServices = boot_services, .PhysicalLimit = page_setup.PhysmapSize };
    const startup = &claims.Handoff.?;
    handoff.initialize(startup) catch {
        splash.fail(messages.ERROR_STARTUP);
        return status.OUT_OF_RESOURCES;
    };
    splash.report(messages.PREPARING_STARTUP);
    const boot_params = handoff.parameters(startup);
    boot_params.Framebuffer = framebuffer;
    boot_params.Kernel = .{
        .PhysicalBase = loaded_image.BaseAddress,
        .VirtualBase = loaded_image.VirtualBase,
        .Size = loaded_image.totalSize(),
        .EntryPoint = loaded_image.EntryPoint,
        .PML4Address = page_setup.getL4Address(),
        .PhysmapBase = layout.PHYSMAP_BASE,
        .PhysmapSize = page_setup.PhysmapSize,
        .StackTop = handoff.stackTop(startup),
        .StackSize = startup.Stack.?.Pages * sizes.PAGE_SIZE,
    };
    boot_params.ACPI = acpi.findACPI(system_table);
    splash.report(messages.SURVEYING_MEMORY);
    splash.report(messages.STARTING_AKIBA);
    boot_params.Splash = splash.getState().*;
    boot_params.Retirement = page_setup.retirementInventory();
    handoff.exit(startup, image_handle) catch {
        if (startup.ExitAttempted) {
            interrupts.disableInterrupts();
            if (splash.isReady()) splash.fail(messages.ERROR_MEMORY_SURVEY);
            assembly.halt.haltLoop();
        }
        splash.fail(messages.ERROR_MEMORY_SURVEY);
        return status.LOAD_ERROR;
    };
    const floating_control = processor.control;
    control.writeCR0((control.readCR0() | floating_control.CR0_MONITOR_COPROCESSOR | floating_control.CR0_NUMERIC_ERROR) &
        ~(floating_control.CR0_EMULATION | floating_control.CR0_TASK_SWITCHED));
    control.writeCR4((control.readCR4() | floating_control.CR4_OS_FXSAVE | floating_control.CR4_OS_XMM_EXCEPTION) & ~floating_control.CR4_OS_XSAVE);
    fpu.initializeFpu();
    const mxcsr = processor.fpu.DEFAULT_MXCSR;
    fpu.loadMXCSR(&mxcsr);
    assembly.jump.jumpToKernel(loaded_image.EntryPoint, handoff.stackTop(startup), handoff.parameterAlias(startup), page_setup.getL4Address());
}
