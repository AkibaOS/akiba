//! Hikari Boot Sequence Runner

const acpi = @import("hikari").sequence.acpi;
const assembly = @import("hikari").assembly;
const boot = @import("shared").boot;
const common = @import("common");
const console = @import("hikari").sequence.console;
const constants = @import("hikari").sequence.constants;
const display = @import("hikari").display;
const efi = @import("hikari").efi;
const fs = @import("hikari").fs;
const graphics = @import("hikari").sequence.graphics;
const loader = @import("hikari").loader;
const paging = @import("hikari").paging;
const partition = @import("hikari").sequence.partition;
const strings = @import("hikari").sequence.strings;

const messages = strings.messages;
const paths = strings.paths;
const layout = common.constants.memory.layout;
const status = efi.constants.status;

pub fn run(image_handle: efi.types.base.Handle, system_table: *efi.services.system.SystemTable) efi.types.base.Status {
    const boot_services = system_table.BootServices;
    const console_output = system_table.ConsoleOutput;

    _ = console_output.ClearScreen(console_output);
    console.print(console_output, messages.TITLE);
    console.print(console_output, messages.TITLE_UNDERLINE);

    console.print(console_output, messages.INITIALIZING_GRAPHICS);
    const gop = graphics.getGraphicsOutput(boot_services) orelse {
        console.print(console_output, messages.ERROR_GRAPHICS_OUTPUT);
        return status.UNSUPPORTED;
    };

    const framebuffer = display.framebuffer.Framebuffer.initialize(gop);
    _ = framebuffer;

    console.print(console_output, messages.LOCATING_AFS_PARTITION);
    const afs_partition = partition.findAfsPartition(boot_services) orelse {
        console.print(console_output, messages.ERROR_AFS_PARTITION_NOT_FOUND);
        return status.NOT_FOUND;
    };

    console.print(console_output, messages.INITIALIZING_AFS);
    var afs_reader = fs.afs.reader.Reader.initialize(
        afs_partition.BlockIO,
        boot_services,
        afs_partition.StartLBA,
    ) catch {
        console.print(console_output, messages.ERROR_AFS_INITIALIZE);
        return status.DEVICE_ERROR;
    };

    console.print(console_output, messages.LOADING_KERNEL);
    console.print(console_output, paths.KERNEL_LOCATION);
    console.print(console_output, messages.NEWLINE);

    const kernel_unit = afs_reader.openLocation(paths.KERNEL_LOCATION) catch {
        console.print(console_output, messages.ERROR_KERNEL_NOT_FOUND);
        return status.NOT_FOUND;
    };

    const kernel_data = afs_reader.readUnitToAllocated(&kernel_unit) catch {
        console.print(console_output, messages.ERROR_KERNEL_READ);
        return status.DEVICE_ERROR;
    };

    console.print(console_output, messages.VALIDATING_ELF);
    if (!loader.elf.loader.validateElf(kernel_data.Buffer, kernel_data.Size)) {
        console.print(console_output, messages.ERROR_INVALID_ELF);
        return status.INVALID_PARAMETER;
    }

    console.print(console_output, messages.LOADING_KERNEL_MEMORY);
    var elf_loader = loader.elf.loader.Loader.initialize(boot_services);
    const loaded_image = elf_loader.load(kernel_data.Buffer, kernel_data.Size) catch {
        console.print(console_output, messages.ERROR_KERNEL_LOAD);
        return status.LOAD_ERROR;
    };

    console.print(console_output, messages.SETTING_UP_PAGE_TABLES);
    var page_setup = paging.setup.PageTableSetup.initialize(boot_services) catch {
        console.print(console_output, messages.ERROR_PAGE_TABLES);
        return status.OUT_OF_RESOURCES;
    };

    page_setup.mapIdentity(0, constants.memory.IDENTITY_MAP_SIZE) catch {};
    page_setup.mapKernel(loaded_image.BaseAddress, loaded_image.totalSize()) catch {};
    page_setup.mapPhysmap(constants.memory.PHYSMAP_MAP_SIZE) catch {};

    console.print(console_output, messages.ALLOCATING_KERNEL_STACK);
    const stack_size = layout.KERNEL_STACK_SIZE;
    const stack_pages = layout.KERNEL_STACK_PAGES;
    var stack_base: efi.types.base.PhysicalAddress = 0;
    const stack_status = boot_services.AllocatePages(.AnyPages, .LoaderData, stack_pages, &stack_base);
    if (efi.types.base.isError(stack_status)) {
        console.print(console_output, messages.ERROR_STACK_ALLOCATION);
        return status.OUT_OF_RESOURCES;
    }
    const stack_top = stack_base + stack_size;

    console.print(console_output, messages.PREPARING_BOOT_PARAMETERS);
    var params_address: efi.types.base.PhysicalAddress = 0;
    const params_status = boot_services.AllocatePages(.AnyPages, .LoaderData, 1, &params_address);
    if (efi.types.base.isError(params_status)) {
        console.print(console_output, messages.ERROR_BOOT_PARAMS_ALLOCATION);
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

    console.print(console_output, messages.GETTING_MEMORY_MAP);
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
        console.print(console_output, messages.ERROR_MEMORY_MAP);
        return status.DEVICE_ERROR;
    }

    boot_params.MemoryMap = boot.types.memory.MemoryMapInfo{
        .Entries = @intFromPtr(memory_map),
        .EntryCount = @truncate(memory_map_size / descriptor_size),
        .EntrySize = @truncate(descriptor_size),
        .DescriptorVersion = descriptor_version,
        .Reserved = 0,
    };

    console.print(console_output, messages.EXITING_BOOT_SERVICES);
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

    assembly.jump.jumpToKernel(
        loaded_image.EntryPoint,
        stack_top,
        params_address,
        page_setup.getL4Address(),
    );
}
