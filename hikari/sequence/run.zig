//! Hikari Boot Sequence Runner

const efi = @import("../efi/efi.zig");
const fs = @import("../fs/fs.zig");
const loader = @import("../loader/loader.zig");
const display = @import("../display/display.zig");
const paging = @import("../paging/paging.zig");
const boot = @import("../boot/boot.zig");
const asm_ops = @import("../asm/asm.zig");

const print = @import("console.zig").print;
const get_graphics_output = @import("graphics.zig").get_graphics_output;
const find_afs_partition = @import("partition.zig").find_afs_partition;
const find_acpi = @import("acpi.zig").find_acpi;
const messages = @import("strings/strings.zig").messages;
const paths = @import("constants/constants.zig").paths;

pub fn run(image_handle: efi.types.Handle, system_table: *efi.services.SystemTable) efi.types.Status {
    const boot_services = system_table.boot_services;
    const console = system_table.console_output;

    _ = console.clear_screen(console);
    print(console, messages.title);
    print(console, messages.title_underline);

    print(console, messages.initializing_graphics);
    const gop = get_graphics_output(boot_services) orelse {
        print(console, messages.error_graphics_output);
        return efi.constants.status.unsupported;
    };

    const framebuffer = display.Framebuffer.initialize(gop);
    _ = framebuffer;

    print(console, messages.locating_afs_partition);
    const afs_partition = find_afs_partition(boot_services) orelse {
        print(console, messages.error_afs_partition_not_found);
        return efi.constants.status.not_found;
    };

    print(console, messages.initializing_afs);
    var afs_reader = fs.afs.Reader.initialize(
        afs_partition.block_io,
        boot_services,
        afs_partition.start_lba,
    ) catch {
        print(console, messages.error_afs_initialize);
        return efi.constants.status.device_error;
    };

    print(console, messages.loading_kernel);
    print(console, paths.kernel_location);
    print(console, messages.newline);

    const kernel_unit = afs_reader.open_location(paths.kernel_location) catch {
        print(console, messages.error_kernel_not_found);
        return efi.constants.status.not_found;
    };

    const kernel_data = afs_reader.read_unit_to_allocated(&kernel_unit) catch {
        print(console, messages.error_kernel_read);
        return efi.constants.status.device_error;
    };

    print(console, messages.validating_elf);
    if (!loader.elf.validate_elf(kernel_data.buffer, kernel_data.size)) {
        print(console, messages.error_invalid_elf);
        return efi.constants.status.invalid_parameter;
    }

    print(console, messages.loading_kernel_memory);
    var elf_loader = loader.elf.Loader.initialize(boot_services);
    const loaded_image = elf_loader.load(kernel_data.buffer, kernel_data.size) catch {
        print(console, messages.error_kernel_load);
        return efi.constants.status.load_error;
    };

    print(console, messages.setting_up_page_tables);
    var page_setup = paging.PageTableSetup.initialize(boot_services) catch {
        print(console, messages.error_page_tables);
        return efi.constants.status.out_of_resources;
    };

    page_setup.map_identity(0, 4 * 1024 * 1024 * 1024) catch {};
    page_setup.map_kernel(loaded_image.base_address, loaded_image.total_size()) catch {};
    page_setup.map_physmap(16 * 1024 * 1024 * 1024) catch {};

    print(console, messages.allocating_kernel_stack);
    const stack_size: u64 = 64 * 1024;
    const stack_pages = stack_size / 4096;
    var stack_base: efi.types.PhysicalAddress = 0;
    const stack_status = boot_services.allocate_pages(.any_pages, .loader_data, stack_pages, &stack_base);
    if (efi.types.is_error(stack_status)) {
        print(console, messages.error_stack_allocation);
        return efi.constants.status.out_of_resources;
    }
    const stack_top = stack_base + stack_size;

    print(console, messages.preparing_boot_parameters);
    var params_addr: efi.types.PhysicalAddress = 0;
    const params_status = boot_services.allocate_pages(.any_pages, .loader_data, 1, &params_addr);
    if (efi.types.is_error(params_status)) {
        print(console, messages.error_boot_params_allocation);
        return efi.constants.status.out_of_resources;
    }

    const boot_params: *boot.BootParams = @ptrFromInt(params_addr);
    boot_params.* = boot.BootParams.initialize();

    boot_params.framebuffer = boot.FramebufferInfo{
        .base = gop.mode.framebuffer_base,
        .size = gop.mode.framebuffer_size,
        .width = gop.mode.info.horizontal_resolution,
        .height = gop.mode.info.vertical_resolution,
        .stride = gop.mode.info.pixels_per_scan_line,
        .pixel_format = switch (gop.mode.info.pixel_format) {
            .rgb => .rgb,
            .bgr => .bgr,
            else => .unknown,
        },
        .red_mask_size = 8,
        .red_mask_shift = 16,
        .green_mask_size = 8,
        .green_mask_shift = 8,
        .blue_mask_size = 8,
        .blue_mask_shift = 0,
        .reserved = .{ 0, 0 },
    };

    boot_params.kernel = boot.KernelInfo{
        .physical_base = loaded_image.base_address,
        .virtual_base = paging.constants.kernel_base,
        .size = loaded_image.total_size(),
        .entry_point = loaded_image.entry_point,
        .pml4_address = page_setup.get_l4_address(),
        .physmap_base = paging.constants.physmap_base,
        .physmap_size = paging.constants.physmap_size,
        .stack_top = stack_top,
        .stack_size = stack_size,
    };

    boot_params.acpi = find_acpi(system_table);

    print(console, messages.getting_memory_map);
    var memory_map_size: usize = 0;
    var map_key: usize = 0;
    var descriptor_size: usize = 0;
    var descriptor_version: u32 = 0;
    var memory_map: [*]efi.types.memory.MemoryDescriptor = undefined;

    _ = boot_services.get_memory_map(
        &memory_map_size,
        memory_map,
        &map_key,
        &descriptor_size,
        &descriptor_version,
    );

    memory_map_size += 2 * descriptor_size;
    var map_buffer: [*]align(8) u8 = undefined;
    _ = boot_services.allocate_pool(.loader_data, memory_map_size, &map_buffer);
    memory_map = @ptrCast(@alignCast(map_buffer));

    const map_status = boot_services.get_memory_map(
        &memory_map_size,
        memory_map,
        &map_key,
        &descriptor_size,
        &descriptor_version,
    );

    if (efi.types.is_error(map_status)) {
        print(console, messages.error_memory_map);
        return efi.constants.status.device_error;
    }

    boot_params.memory_map = boot.MemoryMapInfo{
        .entries = @intFromPtr(memory_map),
        .entry_count = @truncate(memory_map_size / descriptor_size),
        .entry_size = @truncate(descriptor_size),
        .descriptor_version = descriptor_version,
        .reserved = 0,
    };

    print(console, messages.exiting_boot_services);
    const exit_status = boot_services.exit_boot_services(image_handle, map_key);
    if (efi.types.is_error(exit_status)) {
        _ = boot_services.get_memory_map(
            &memory_map_size,
            memory_map,
            &map_key,
            &descriptor_size,
            &descriptor_version,
        );
        _ = boot_services.exit_boot_services(image_handle, map_key);
    }

    asm_ops.jump_to_kernel(
        loaded_image.entry_point,
        stack_top,
        params_addr,
        page_setup.get_l4_address(),
    );
}
