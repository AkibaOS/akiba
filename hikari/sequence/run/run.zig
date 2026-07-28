//! Hikari Boot Sequence Runner

const acpi = @import("hikari").sequence.acpi;
const assembly = @import("hikari").assembly;
const boot = @import("shared").boot;
const common = @import("common");
const console = @import("hikari").sequence.console;
const constants = @import("hikari").sequence.constants;
const efi = @import("hikari").efi;
const fs = @import("hikari").fs;
const graphics = @import("hikari").sequence.graphics;
const loader = @import("hikari").loader;
const paging = @import("hikari").paging;
const partition = @import("hikari").sequence.partition;
const splash = @import("hikari").sequence.splash;
const strings = @import("hikari").sequence.strings;

const messages = strings.messages;
const paths = strings.paths;
const layout = common.constants.memory.layout;
const status = efi.constants.status;

pub fn run(image_handle: efi.types.base.Handle, system_table: *efi.services.system.SystemTable) efi.types.base.Status {
    const boot_services = system_table.BootServices;
    const console_output = system_table.ConsoleOutput;

    _ = console_output.ClearScreen(console_output);

    const gop = graphics.getGraphicsOutput(boot_services) orelse {
        console.print(console_output, messages.ERROR_DISPLAY);
        return status.UNSUPPORTED;
    };

    _ = splash.initialize(gop, console_output);
    splash.report(messages.INITIALIZING_DISPLAY);

    splash.report(messages.LOCATING_FILE_SYSTEM);
    const afs_partition = partition.findAfsPartition(boot_services) orelse {
        splash.fail(messages.ERROR_FILE_SYSTEM_NOT_FOUND);
        return status.NOT_FOUND;
    };

    splash.report(messages.INITIALIZING_FILE_SYSTEM);
    var afs_reader = fs.afs.reader.Reader.initialize(
        afs_partition.BlockIO,
        boot_services,
        afs_partition.StartLBA,
    ) catch {
        splash.fail(messages.ERROR_FILE_SYSTEM);
        return status.DEVICE_ERROR;
    };

    splash.report(messages.LOADING_KERNEL);

    const kernel_unit = afs_reader.openLocation(paths.KERNEL_LOCATION) catch {
        splash.fail(messages.ERROR_KERNEL_NOT_FOUND);
        return status.NOT_FOUND;
    };

    const kernel_data = afs_reader.readUnitToAllocated(&kernel_unit) catch {
        splash.fail(messages.ERROR_KERNEL_READ);
        return status.DEVICE_ERROR;
    };

    splash.report(messages.VERIFYING_KERNEL);
    if (!loader.elf.loader.validateElf(kernel_data.Buffer, kernel_data.Size)) {
        splash.fail(messages.ERROR_KERNEL_DAMAGED);
        return status.INVALID_PARAMETER;
    }

    splash.report(messages.PREPARING_KERNEL);
    var elf_loader = loader.elf.loader.Loader.initialize(boot_services);
    const loaded_image = elf_loader.load(kernel_data.Buffer, kernel_data.Size) catch {
        splash.fail(messages.ERROR_KERNEL_LOAD);
        return status.LOAD_ERROR;
    };

    splash.report(messages.PREPARING_MEMORY);
    var page_setup = paging.setup.PageTableSetup.initialize(boot_services) catch {
        splash.fail(messages.ERROR_MEMORY);
        return status.OUT_OF_RESOURCES;
    };

    page_setup.mapIdentity(0, constants.memory.IDENTITY_MAP_SIZE) catch {};
    page_setup.mapKernel(loaded_image.BaseAddress, loaded_image.totalSize()) catch {};
    page_setup.mapPhysmap(constants.memory.PHYSMAP_MAP_SIZE) catch {};

    splash.report(messages.RESERVING_KERNEL_MEMORY);
    const stack_size = layout.KERNEL_STACK_SIZE;
    const stack_pages = layout.KERNEL_STACK_PAGES;
    var stack_base: efi.types.base.PhysicalAddress = 0;
    const stack_status = boot_services.AllocatePages(.AnyPages, .LoaderData, stack_pages, &stack_base);
    if (efi.types.base.isError(stack_status)) {
        splash.fail(messages.ERROR_KERNEL_MEMORY);
        return status.OUT_OF_RESOURCES;
    }
    const stack_top = stack_base + stack_size;

    splash.report(messages.PREPARING_STARTUP);
    var params_address: efi.types.base.PhysicalAddress = 0;
    const params_status = boot_services.AllocatePages(.AnyPages, .LoaderData, 1, &params_address);
    if (efi.types.base.isError(params_status)) {
        splash.fail(messages.ERROR_STARTUP);
        return status.OUT_OF_RESOURCES;
    }

    const boot_params: *boot.types.params.BootParams = @ptrFromInt(params_address);
    boot_params.* = boot.types.params.BootParams.initialize();

    boot_params.Framebuffer = boot.types.framebuffer.FramebufferInfo{
        .Base = gop.Mode.FramebufferBase,
        .Size = gop.Mode.FramebufferSize,
        .Width = gop.Mode.Info.HorizontalResolution,
        .Height = gop.Mode.Info.VerticalResolution,
        .Stride = gop.Mode.Info.PixelsPerScanLine,
        .PixelFormat = switch (gop.Mode.Info.PixelFormat) {
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

    boot_params.Kernel = boot.types.kernel.KernelInfo{
        .PhysicalBase = loaded_image.BaseAddress,
        .VirtualBase = layout.KERNEL_BASE,
        .Size = loaded_image.totalSize(),
        .EntryPoint = loaded_image.EntryPoint,
        .PML4Address = page_setup.getL4Address(),
        .PhysmapBase = layout.PHYSMAP_BASE,
        .PhysmapSize = layout.PHYSMAP_MAX_SIZE,
        .StackTop = stack_top,
        .StackSize = stack_size,
    };

    boot_params.ACPI = acpi.findACPI(system_table);

    splash.report(messages.SURVEYING_MEMORY);
    var memory_map_size: usize = 0;
    var map_key: usize = 0;
    var descriptor_size: usize = 0;
    var descriptor_version: u32 = 0;
    var memory_map: [*]efi.types.memory.MemoryDescriptor = undefined;

    _ = boot_services.GetMemoryMap(
        &memory_map_size,
        memory_map,
        &map_key,
        &descriptor_size,
        &descriptor_version,
    );

    memory_map_size += constants.memory.MEMORY_MAP_EXTRA_DESCRIPTORS * descriptor_size;
    var map_buffer: [*]align(8) u8 = undefined;
    _ = boot_services.AllocatePool(.LoaderData, memory_map_size, &map_buffer);
    memory_map = @ptrCast(@alignCast(map_buffer));

    const map_status = boot_services.GetMemoryMap(
        &memory_map_size,
        memory_map,
        &map_key,
        &descriptor_size,
        &descriptor_version,
    );

    if (efi.types.base.isError(map_status)) {
        splash.fail(messages.ERROR_MEMORY_SURVEY);
        return status.DEVICE_ERROR;
    }

    boot_params.MemoryMap = boot.types.memory.MemoryMapInfo{
        .Entries = @intFromPtr(memory_map),
        .EntryCount = @truncate(memory_map_size / descriptor_size),
        .EntrySize = @truncate(descriptor_size),
        .DescriptorVersion = descriptor_version,
        .Reserved = 0,
    };

    splash.report(messages.STARTING_AKIBA);
    const exit_status = boot_services.ExitBootServices(image_handle, map_key);
    if (efi.types.base.isError(exit_status)) {
        _ = boot_services.GetMemoryMap(
            &memory_map_size,
            memory_map,
            &map_key,
            &descriptor_size,
            &descriptor_version,
        );
        _ = boot_services.ExitBootServices(image_handle, map_key);
    }

    boot_params.Splash = splash.getState().*;

    assembly.jump.jumpToKernel(
        loaded_image.EntryPoint,
        stack_top,
        params_address,
        page_setup.getL4Address(),
    );
}
