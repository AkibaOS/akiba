//! Hikari - The ELF loader
//! Hikari (光) = Light - illuminates programs into execution

const ahci = @import("../drivers/ahci.zig");
const afs = @import("../fs/afs.zig");
const elf = @import("elf.zig");
const format = @import("format.zig");
const gdt = @import("../boot/gdt.zig");
const kata_mod = @import("../kata/kata.zig");
const paging = @import("../memory/paging.zig");
const pmm = @import("../memory/pmm.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");

const PAGE_SIZE: u64 = 4096;
const HIGHER_HALF: u64 = 0xFFFF800000000000;

pub fn init() void {
    serial.print("\n=== Hikari Loader ===\n");
    serial.print("Akiba executable loader initialized\n");
}

pub fn load_init_system(fs: *afs.AFS(ahci.BlockDevice)) !u32 {
    serial.print("\n=== Loading Init System ===\n");

    const pulse_path = "/system/akiba/pulse.akibainit";
    return load_program(fs, pulse_path);
}

pub fn load_program(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) !u32 {
    serial.print("\n=== Loading Program ===\n");
    serial.print("Path: ");
    serial.print(path);
    serial.print("\n");

    var file_buffer: [1024 * 1024]u8 = undefined;
    const bytes_read = try fs.read_file_by_path(path, &file_buffer);

    const file_data = file_buffer[0..bytes_read];
    const akiba_exe = try format.parse_akiba(file_data);
    const elf_info = try elf.parse_elf(akiba_exe.elf_data);

    const new_kata = try kata_mod.create_kata();

    try setup_kata_memory(new_kata, &elf_info, akiba_exe.elf_data);
    setup_kata_context(new_kata, elf_info.entry_point);

    sensei.enqueue_kata(new_kata);

    serial.print("Kata ");
    serial.print_hex(new_kata.id);
    serial.print(" ready\n");

    return new_kata.id;
}

fn setup_kata_memory(kata: *kata_mod.Kata, elf_info: *const elf.ELFInfo, elf_data: []const u8) !void {
    // Create isolated page table for this process
    kata.page_table = try paging.create_page_table();

    serial.print("Kata page table: ");
    serial.print_hex(kata.page_table);
    serial.print("\n");

    // Load program segments at their original ELF addresses
    for (elf_info.program_headers) |ph| {
        if (ph.type == elf.PT_LOAD) {
            try load_segment(kata, ph, elf_data);
        }
    }

    // Allocate user stack in high canonical address
    const user_stack_base: u64 = 0x00007FFFFFF00000;
    const user_stack_size: u64 = PAGE_SIZE * 4;

    try allocate_user_stack(kata, user_stack_base, user_stack_size);
    kata.user_stack_top = user_stack_base + user_stack_size;

    serial.print("User stack: ");
    serial.print_hex(kata.user_stack_top);
    serial.print("\n");

    // Allocate kernel stack in higher-half
    const kernel_stack_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    kata.stack_top = kernel_stack_phys + HIGHER_HALF + PAGE_SIZE;

    serial.print("Kernel stack: ");
    serial.print_hex(kata.stack_top);
    serial.print("\n");
}

fn load_segment(kata: *kata_mod.Kata, ph: elf.ELF64ProgramHeader, elf_data: []const u8) !void {
    serial.print("Loading segment at ");
    serial.print_hex(ph.vaddr);
    serial.print(", size: ");
    serial.print_hex(ph.memsz);
    serial.print(", file offset: ");
    serial.print_hex(ph.offset);
    serial.print("\n");

    var vaddr = ph.vaddr;
    var remaining = ph.memsz;
    var file_offset: u64 = 0;

    while (remaining > 0) {
        const page_base = vaddr & ~@as(u64, PAGE_SIZE - 1);
        const offset_in_page = vaddr - page_base;
        const bytes_in_page = @min(PAGE_SIZE - offset_in_page, remaining);

        // Allocate and map page
        const phys_page = pmm.alloc_page() orelse return error.OutOfMemory;
        const result = try paging.map_page_in_table(kata.page_table, page_base, phys_page, 0b111);
        const was_mapped = result[0];
        const actual_phys = result[1];

        // DEBUG: Verify mapping
        if (page_base == 0x400000) {
            serial.print("DEBUG: Mapped 0x400000 -> phys ");
            serial.print_hex(actual_phys);
            serial.print(", was_mapped=");
            serial.print(if (was_mapped) "true\n" else "false\n");

            // Verify we can read it back
            const verify_phys = paging.get_physical_address(kata.page_table, 0x400000) catch 0;
            serial.print("DEBUG: Verify readback: ");
            serial.print_hex(verify_phys);
            serial.print("\n");
        }

        if (was_mapped) {
            pmm.free_page(phys_page);
        }

        // Zero page and write segment data
        const dest_base = @as([*]u8, @ptrFromInt(actual_phys + HIGHER_HALF));

        if (!was_mapped) {
            var i: usize = 0;
            while (i < PAGE_SIZE) : (i += 1) {
                dest_base[i] = 0;
            }
        }

        if (file_offset < ph.filesz) {
            const file_bytes = @min(bytes_in_page, ph.filesz - file_offset);
            const src_offset = ph.offset + file_offset;
            const src = elf_data[src_offset .. src_offset + file_bytes];

            const dest = dest_base + offset_in_page;
            for (src, 0..) |byte, j| {
                dest[j] = byte;
            }
        }

        vaddr += bytes_in_page;
        file_offset += bytes_in_page;
        remaining -= bytes_in_page;
    }

    // Verify entry point was loaded correctly
    if (ph.vaddr == 0x400000) {
        serial.print("DEBUG: Verifying entry point at 0x");
        serial.print_hex(ph.vaddr);
        serial.print(":\n  Bytes: ");
        const page_phys = paging.get_physical_address(kata.page_table, 0x400000) catch 0;
        if (page_phys != 0) {
            const bytes = @as([*]u8, @ptrFromInt(page_phys + HIGHER_HALF));
            var i: usize = 0;
            while (i < 32) : (i += 1) {
                serial.print_hex(bytes[i]);
                serial.print(" ");
            }
            serial.print("\n");
        }
    }
}

fn allocate_user_stack(kata: *kata_mod.Kata, base: u64, size: u64) !void {
    var addr = base;
    var remaining = size;

    while (remaining > 0) {
        const phys_page = pmm.alloc_page() orelse return error.OutOfMemory;

        const flags: u64 = 0b111; // Present + Writable + User
        const result = try paging.map_page_in_table(kata.page_table, addr, phys_page, flags);
        const was_mapped = result[0];
        const actual_phys = result[1];

        if (was_mapped) {
            pmm.free_page(phys_page);
        }

        // Zero the stack page
        const dest = @as([*]u8, @ptrFromInt(actual_phys + HIGHER_HALF));
        var i: usize = 0;
        while (i < PAGE_SIZE) : (i += 1) {
            dest[i] = 0;
        }

        addr += PAGE_SIZE;
        remaining -= PAGE_SIZE;
    }
}

fn setup_kata_context(kata: *kata_mod.Kata, entry_point: u64) void {
    kata.context.rip = entry_point;
    kata.context.rsp = kata.user_stack_top;
    kata.context.rflags = 0x3202;
    kata.context.cs = gdt.USER_CODE | 3;
    kata.context.ss = gdt.USER_DATA | 3;
}
