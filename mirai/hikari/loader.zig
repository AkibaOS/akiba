//! Hikari - The ELF loader
//! Hikari (光) = Light - illuminates programs into execution

const serial = @import("../drivers/serial.zig");
const heap = @import("../memory/heap.zig");
const pmm = @import("../memory/pmm.zig");
const paging = @import("../memory/paging.zig");
const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const elf = @import("elf.zig");
const format = @import("format.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const gdt = @import("../boot/gdt.zig");
const boot = @import("../boot/multiboot2.zig");

const HIGHER_HALF: u64 = 0xFFFF800000000000;
const USER_STACK_TOP: u64 = 0x00007FFFFFF00000;
const USER_STACK_PAGES: u64 = 64; // 256KB stack (was 4 pages = 16KB)

pub fn init() void {}

pub fn load_init_system(fs: *afs.AFS(ahci.BlockDevice)) !u32 {
    return load_program(fs, "/system/akiba/pulse.akibainit");
}

pub fn load_program(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) !u32 {
    // Allocate file buffer directly from PMM (2MB is too large for heap slab allocator)
    const buffer_size: usize = 2 * 1024 * 1024;
    const num_pages = (buffer_size + 0xFFF) / 0x1000; // 512 pages

    // Allocate pages and track them in a fixed array
    var pages: [512]u64 = undefined;
    var pages_allocated: usize = 0;

    var i: usize = 0;
    while (i < num_pages) : (i += 1) {
        const page = pmm.alloc_page() orelse {
            // Free already allocated pages on error
            var j: usize = 0;
            while (j < pages_allocated) : (j += 1) {
                pmm.free_page(pages[j]);
            }
            return error.OutOfMemory;
        };
        pages[i] = page;
        pages_allocated += 1;
    }
    defer {
        var j: usize = 0;
        while (j < pages_allocated) : (j += 1) {
            pmm.free_page(pages[j]);
        }
    }

    // Map all pages into a contiguous virtual buffer
    // For simplicity, just use the physical pages directly via higher half mapping
    // This assumes PMM returns reasonably contiguous pages
    const file_buffer_phys = pages[0];
    const file_buffer_ptr = @as([*]u8, @ptrFromInt(file_buffer_phys + HIGHER_HALF));
    const file_buffer = file_buffer_ptr[0..buffer_size];

    const bytes_read = fs.read_file_by_path(path, file_buffer) catch |err| {
        return err;
    };

    const akiba_data = format.parse_akiba(file_buffer[0..bytes_read]) catch |err| {
        return err;
    };

    const elf_info = elf.parse_elf(akiba_data.elf_data) catch |err| {
        return err;
    };

    const kata = kata_mod.create_kata() catch |err| {
        return err;
    };

    setup_kata_memory(kata, akiba_data.elf_data, elf_info) catch |err| {
        kata_mod.dissolve_kata(kata.id);
        return err;
    };

    setup_kata_context(kata, elf_info.entry_point);
    sensei.enqueue_kata(kata);

    return kata.id;
}

fn setup_kata_memory(kata: *kata_mod.Kata, elf_data: []const u8, elf_info: elf.ELFInfo) !void {
    const new_cr3 = try paging.create_page_table();
    kata.page_table = new_cr3;

    for (elf_info.program_headers) |phdr| {
        if (phdr.type == elf.PT_LOAD) {
            try load_segment(kata.page_table, elf_data, phdr);
        }
    }

    const user_stack_base = USER_STACK_TOP - (USER_STACK_PAGES * 0x1000);
    var i: u64 = 0;
    while (i < USER_STACK_PAGES) : (i += 1) {
        const page_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        const page_virt = user_stack_base + (i * 0x1000);

        _ = try paging.map_page_in_table(kata.page_table, page_virt, page_phys, 0b111);

        const zero_ptr = @as([*]volatile u8, @ptrFromInt(page_phys + HIGHER_HALF));
        @memset(zero_ptr[0..0x1000], 0);
    }

    kata.user_stack_top = USER_STACK_TOP;

    const kernel_stack_page = pmm.alloc_page() orelse return error.OutOfMemory;
    kata.stack_top = kernel_stack_page + HIGHER_HALF + 0x1000;

    if (boot.get_framebuffer()) |fb_info| {
        const fb_start = fb_info.addr;
        const fb_size = fb_info.height * fb_info.pitch;
        const fb_pages = (fb_size + 0xFFF) / 0x1000;

        var page: u64 = 0;
        while (page < fb_pages) : (page += 1) {
            const phys = fb_start + (page * 0x1000);
            const virt = phys;

            _ = try paging.map_page_in_table(kata.page_table, virt, phys, 0b111);
        }
    }
}

fn load_segment(cr3: u64, elf_data: []const u8, phdr: elf.ELF64ProgramHeader) !void {
    const start_addr = phdr.vaddr;
    const mem_size = phdr.memsz;
    const file_size = phdr.filesz;

    const start_page = start_addr & ~@as(u64, 0xFFF);
    const end_addr = start_addr + mem_size;
    const end_page = (end_addr + 0xFFF) & ~@as(u64, 0xFFF);
    const num_pages = (end_page - start_page) / 0x1000;

    var page_idx: u64 = 0;
    while (page_idx < num_pages) : (page_idx += 1) {
        const page_virt = start_page + (page_idx * 0x1000);
        const page_phys = pmm.alloc_page() orelse return error.OutOfMemory;

        _ = try paging.map_page_in_table(cr3, page_virt, page_phys, 0b111);

        const zero_ptr = @as([*]volatile u8, @ptrFromInt(page_phys + HIGHER_HALF));
        @memset(zero_ptr[0..0x1000], 0);
    }

    if (file_size > 0) {
        const source = elf_data[phdr.offset .. phdr.offset + file_size];

        var copied: u64 = 0;
        while (copied < file_size) {
            const virt_addr = start_addr + copied;
            const page_virt = virt_addr & ~@as(u64, 0xFFF);

            const phys = paging.virt_to_phys(cr3, page_virt) orelse return error.PageNotMapped;

            const page_offset = virt_addr & 0xFFF;
            const bytes_in_page = @min(0x1000 - page_offset, file_size - copied);

            const dest_ptr = @as([*]volatile u8, @ptrFromInt(phys + HIGHER_HALF + page_offset));
            const src_ptr = source[copied .. copied + bytes_in_page];

            @memcpy(dest_ptr[0..bytes_in_page], src_ptr);
            copied += bytes_in_page;
        }
    }
}

fn setup_kata_context(kata: *kata_mod.Kata, entry_point: u64) void {
    kata.context.rip = entry_point;
    kata.context.rsp = kata.user_stack_top;
    kata.context.rflags = 0x3202;
    kata.context.cs = gdt.USER_CODE | 3;
    kata.context.ss = gdt.USER_DATA | 3;

    kata.context.rax = 0;
    kata.context.rbx = 0;
    kata.context.rcx = 0;
    kata.context.rdx = 0;
    kata.context.rsi = 0;
    kata.context.rdi = 0;
    kata.context.rbp = 0;
    kata.context.r8 = 0;
    kata.context.r9 = 0;
    kata.context.r10 = 0;
    kata.context.r11 = 0;
    kata.context.r12 = 0;
    kata.context.r13 = 0;
    kata.context.r14 = 0;
    kata.context.r15 = 0;
}
