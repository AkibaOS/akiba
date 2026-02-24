//! Hikari ELF Loader

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const LoadError = error{
    invalid_elf_header,
    unsupported_architecture,
    unsupported_elf_type,
    no_loadable_segments,
    too_many_segments,
    allocation_failed,
    segment_overlap,
};

pub const Loader = struct {
    boot_services: *efi.services.BootServices,

    pub fn initialize(boot_services: *efi.services.BootServices) Loader {
        return Loader{
            .boot_services = boot_services,
        };
    }

    pub fn load(self: *Loader, unit_data: [*]const u8, unit_size: u64) LoadError!types.LoadedImage {
        if (unit_size < constants.elf64_header_size) {
            return LoadError.invalid_elf_header;
        }

        const header: *const types.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.is_valid()) {
            return LoadError.invalid_elf_header;
        }

        if (!header.is_x86_64()) {
            return LoadError.unsupported_architecture;
        }

        if (!header.is_executable()) {
            return LoadError.unsupported_elf_type;
        }

        const program_headers = header.get_program_headers(unit_data);

        var load_base: u64 = 0xFFFFFFFFFFFFFFFF;
        var load_end: u64 = 0;
        var loadable_count: usize = 0;

        for (program_headers) |*phdr| {
            if (!phdr.is_loadable()) {
                continue;
            }

            loadable_count += 1;

            if (phdr.virtual_address < load_base) {
                load_base = phdr.virtual_address;
            }

            const segment_end = phdr.virtual_address + phdr.memory_size;
            if (segment_end > load_end) {
                load_end = segment_end;
            }
        }

        if (loadable_count == 0) {
            return LoadError.no_loadable_segments;
        }

        if (loadable_count > 16) {
            return LoadError.too_many_segments;
        }

        const total_size = load_end - load_base;
        const pages_needed = (total_size + 4095) / 4096;

        var physical_base: efi.types.PhysicalAddress = load_base;
        const alloc_status = self.boot_services.allocate_pages(
            .address,
            .loader_data,
            pages_needed,
            &physical_base,
        );

        if (efi.types.is_error(alloc_status)) {
            physical_base = 0;
            const fallback_status = self.boot_services.allocate_pages(
                .any_pages,
                .loader_data,
                pages_needed,
                &physical_base,
            );

            if (efi.types.is_error(fallback_status)) {
                return LoadError.allocation_failed;
            }
        }

        const dest_base: [*]u8 = @ptrFromInt(physical_base);

        var i: u64 = 0;
        while (i < total_size) : (i += 1) {
            dest_base[i] = 0;
        }

        var image = types.LoadedImage{
            .entry_point = header.entry,
            .base_address = physical_base,
            .end_address = physical_base + total_size,
            .segments = undefined,
            .segment_count = 0,
        };

        for (program_headers) |*phdr| {
            if (!phdr.is_loadable()) {
                continue;
            }

            const segment_offset = phdr.virtual_address - load_base;
            const dest: [*]u8 = dest_base + segment_offset;
            const src = unit_data + phdr.offset;

            var j: u64 = 0;
            while (j < phdr.unit_size) : (j += 1) {
                dest[j] = src[j];
            }

            image.segments[image.segment_count] = types.LoadedSegment{
                .virtual_address = phdr.virtual_address,
                .physical_address = physical_base + segment_offset,
                .memory_size = phdr.memory_size,
                .flags = phdr.flags,
            };
            image.segment_count += 1;
        }

        if (physical_base != load_base) {
            image.entry_point = (header.entry - load_base) + physical_base;
        }

        return image;
    }

    pub fn get_memory_requirements(unit_data: [*]const u8) LoadError!struct { base: u64, size: u64 } {
        const header: *const types.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.is_valid()) {
            return LoadError.invalid_elf_header;
        }

        const program_headers = header.get_program_headers(unit_data);

        var load_base: u64 = 0xFFFFFFFFFFFFFFFF;
        var load_end: u64 = 0;

        for (program_headers) |*phdr| {
            if (!phdr.is_loadable()) {
                continue;
            }

            if (phdr.virtual_address < load_base) {
                load_base = phdr.virtual_address;
            }

            const segment_end = phdr.virtual_address + phdr.memory_size;
            if (segment_end > load_end) {
                load_end = segment_end;
            }
        }

        if (load_base == 0xFFFFFFFFFFFFFFFF) {
            return LoadError.no_loadable_segments;
        }

        return .{
            .base = load_base,
            .size = load_end - load_base,
        };
    }

    pub fn get_entry_point(unit_data: [*]const u8) LoadError!u64 {
        const header: *const types.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.is_valid()) {
            return LoadError.invalid_elf_header;
        }

        return header.entry;
    }
};

pub fn validate_elf(data: [*]const u8, size: u64) bool {
    if (size < constants.elf64_header_size) {
        return false;
    }

    const header: *const types.Elf64Header = @ptrCast(@alignCast(data));
    return header.is_valid() and header.is_x86_64();
}
