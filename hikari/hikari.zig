//! Hikari UEFI Bootloader for AkibaOS
//!
//! Hikari loads the Mirai kernel from the AFS partition and
//! transfers control with boot parameters.

const std = @import("std");
const efi = @import("efi/efi.zig");
const disk = @import("disk/disk.zig");
const fs = @import("fs/fs.zig");
const loader = @import("loader/loader.zig");
const display = @import("display/display.zig");
const menu = @import("menu/menu.zig");
const paging = @import("paging/paging.zig");
const boot = @import("boot/boot.zig");
const asm_ops = @import("asm/asm.zig");

const kernel_location = "/system/akiba/mirai.kernel";
const font_location = "/system/akiba/fonts/akiba.psf";

pub fn main() void {
    const image_handle: efi.types.Handle = @ptrCast(std.os.uefi.handle);
    const system_table: *efi.services.SystemTable = @ptrCast(std.os.uefi.system_table);
    _ = hikari(image_handle, system_table);
}

fn hikari(image_handle: efi.types.Handle, system_table: *efi.services.SystemTable) efi.types.Status {
    const boot_services = system_table.boot_services;
    const console = system_table.console_output;

    _ = console.clear_screen(console);
    print(console, "Hikari Bootloader\r\n");
    print(console, "=================\r\n\r\n");

    print(console, "Initializing graphics...\r\n");
    const gop = get_graphics_output(boot_services) orelse {
        print(console, "ERROR: Failed to get graphics output\r\n");
        return efi.constants.status.unsupported;
    };

    const framebuffer = display.Framebuffer.initialize(gop);
    _ = framebuffer;

    print(console, "Locating AFS partition...\r\n");
    const afs_partition = find_afs_partition(boot_services) orelse {
        print(console, "ERROR: AFS partition not found\r\n");
        return efi.constants.status.not_found;
    };

    print(console, "Initializing AFS...\r\n");
    var afs_reader = fs.afs.Reader.initialize(
        afs_partition.block_io,
        boot_services,
        afs_partition.start_lba,
    ) catch {
        print(console, "ERROR: Failed to initialize AFS\r\n");
        return efi.constants.status.device_error;
    };

    print(console, "Loading kernel: ");
    print(console, kernel_location);
    print(console, "\r\n");

    const kernel_unit = afs_reader.open_location(kernel_location) catch {
        print(console, "ERROR: Kernel not found\r\n");
        return efi.constants.status.not_found;
    };

    const kernel_data = afs_reader.read_unit_to_allocated(&kernel_unit) catch {
        print(console, "ERROR: Failed to read kernel\r\n");
        return efi.constants.status.device_error;
    };

    print(console, "Validating ELF...\r\n");
    if (!loader.elf.validate_elf(kernel_data.buffer, kernel_data.size)) {
        print(console, "ERROR: Invalid ELF format\r\n");
        return efi.constants.status.invalid_parameter;
    }

    print(console, "Loading kernel into memory...\r\n");
    var elf_loader = loader.elf.Loader.initialize(boot_services);
    const loaded_image = elf_loader.load(kernel_data.buffer, kernel_data.size) catch {
        print(console, "ERROR: Failed to load kernel\r\n");
        return efi.constants.status.load_error;
    };

    print(console, "Setting up page tables...\r\n");
    var page_setup = paging.PageTableSetup.initialize(boot_services) catch {
        print(console, "ERROR: Failed to setup page tables\r\n");
        return efi.constants.status.out_of_resources;
    };

    page_setup.map_identity(0, 4 * 1024 * 1024 * 1024) catch {};
    page_setup.map_kernel(loaded_image.base_address, loaded_image.total_size()) catch {};
    page_setup.map_physmap(16 * 1024 * 1024 * 1024) catch {};

    print(console, "Allocating kernel stack...\r\n");
    const stack_size: u64 = 64 * 1024;
    const stack_pages = stack_size / 4096;
    var stack_base: efi.types.PhysicalAddress = 0;
    const stack_status = boot_services.allocate_pages(.any_pages, .loader_data, stack_pages, &stack_base);
    if (efi.types.is_error(stack_status)) {
        print(console, "ERROR: Failed to allocate stack\r\n");
        return efi.constants.status.out_of_resources;
    }
    const stack_top = stack_base + stack_size;

    print(console, "Preparing boot parameters...\r\n");
    var params_addr: efi.types.PhysicalAddress = 0;
    const params_status = boot_services.allocate_pages(.any_pages, .loader_data, 1, &params_addr);
    if (efi.types.is_error(params_status)) {
        print(console, "ERROR: Failed to allocate boot params\r\n");
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
        .pml4_address = page_setup.get_pml4_address(),
        .physmap_base = paging.constants.physmap_base,
        .physmap_size = paging.constants.physmap_size,
        .stack_top = stack_top,
        .stack_size = stack_size,
    };

    boot_params.acpi = find_acpi(system_table);

    print(console, "Getting memory map...\r\n");
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
        print(console, "ERROR: Failed to get memory map\r\n");
        return efi.constants.status.device_error;
    }

    boot_params.memory_map = boot.MemoryMapInfo{
        .entries = @intFromPtr(memory_map),
        .entry_count = @truncate(memory_map_size / descriptor_size),
        .entry_size = @truncate(descriptor_size),
        .descriptor_version = descriptor_version,
        .reserved = 0,
    };

    print(console, "Exiting boot services...\r\n");
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
        page_setup.get_pml4_address(),
    );
}

fn print(console: *efi.protocols.SimpleTextOutputProtocol, msg: []const u8) void {
    for (msg) |c| {
        var buf = [2:0]u16{ c, 0 };
        _ = console.output_string(console, &buf);
    }
}

fn get_graphics_output(boot_services: *efi.services.BootServices) ?*efi.protocols.GraphicsOutputProtocol {
    var gop: ?*anyopaque = null;
    const status = boot_services.locate_protocol(
        &efi.constants.guids.graphics_output_protocol,
        null,
        &gop,
    );
    if (efi.types.is_error(status)) {
        return null;
    }
    return @ptrCast(@alignCast(gop));
}

const PartitionInfo = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    start_lba: u64,
};

fn find_afs_partition(boot_services: *efi.services.BootServices) ?PartitionInfo {
    var handle_count: usize = 0;
    var handles: [*]efi.types.Handle = undefined;

    const status = boot_services.locate_handle_buffer(
        .by_protocol,
        &efi.constants.guids.block_io_protocol,
        null,
        &handle_count,
        &handles,
    );

    if (efi.types.is_error(status)) {
        return null;
    }

    var i: usize = 0;
    while (i < handle_count) : (i += 1) {
        var block_io: ?*anyopaque = null;
        const bio_status = boot_services.handle_protocol(
            handles[i],
            &efi.constants.guids.block_io_protocol,
            &block_io,
        );

        if (efi.types.is_error(bio_status)) {
            continue;
        }

        const bio: *efi.protocols.BlockIoProtocol = @ptrCast(@alignCast(block_io));

        if (bio.media.logical_partition) {
            continue;
        }

        var gpt_parser = disk.gpt.Parser.initialize(bio, boot_services) catch {
            continue;
        };

        const afs_part = gpt_parser.find_partition_by_type(efi.constants.guids.gpt_partition_type_akiba_afs);
        if (afs_part) |part| {
            return PartitionInfo{
                .block_io = bio,
                .start_lba = part.starting_lba,
            };
        }
    }

    return null;
}

fn find_acpi(system_table: *efi.services.SystemTable) boot.AcpiInfo {
    var i: usize = 0;
    while (i < system_table.number_of_table_entries) : (i += 1) {
        const entry = &system_table.configuration_table[i];

        if (entry.vendor_guid.equals(efi.constants.guids.acpi_20_table)) {
            return boot.AcpiInfo{
                .rsdp_address = @intFromPtr(entry.vendor_table),
                .rsdp_version = 2,
                .reserved = 0,
            };
        }
    }

    i = 0;
    while (i < system_table.number_of_table_entries) : (i += 1) {
        const entry = &system_table.configuration_table[i];

        if (entry.vendor_guid.equals(efi.constants.guids.acpi_10_table)) {
            return boot.AcpiInfo{
                .rsdp_address = @intFromPtr(entry.vendor_table),
                .rsdp_version = 1,
                .reserved = 0,
            };
        }
    }

    return boot.AcpiInfo{
        .rsdp_address = 0,
        .rsdp_version = 0,
        .reserved = 0,
    };
}

pub fn panic(msg: []const u8, stack_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = stack_trace;
    _ = ret_addr;
    asm_ops.halt();
}
