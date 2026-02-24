//! Kata memory management

const asm_memory = @import("../asm/memory.zig");
const memory_const = @import("../common/constants/memory.zig");
const memory_limits = @import("../common/limits/memory.zig");
const paging = @import("../memory/paging.zig");
const paging_const = @import("../common/constants/paging.zig");
const pmm = @import("../memory/pmm.zig");
const types = @import("types.zig");

const HIGHER_HALF = memory_const.HIGHER_HALF_START;
const PAGE_SIZE = memory_const.PAGE_SIZE;

const KERNEL_VMALLOC_START: u64 = 0xFFFFFF8000000000;
var next_vmalloc_addr: u64 = KERNEL_VMALLOC_START;

pub const VirtualBuffer = struct {
    data: []u8,
    virt_base: u64,
    phys_pages: [1024]u64,
    num_pages: usize,

    pub fn alloc(size: usize) !VirtualBuffer {
        const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
        if (num_pages > 1024) return error.AllocationTooLarge;

        var buffer: VirtualBuffer = undefined;
        buffer.num_pages = num_pages;

        var i: usize = 0;
        errdefer {
            var j: usize = 0;
            while (j < i) : (j += 1) {
                pmm.free_page(buffer.phys_pages[j]);
            }
        }

        while (i < num_pages) : (i += 1) {
            buffer.phys_pages[i] = pmm.alloc_page() orelse return error.OutOfMemory;
        }

        buffer.virt_base = next_vmalloc_addr;
        next_vmalloc_addr += num_pages * PAGE_SIZE;

        i = 0;
        errdefer {
            var j: usize = 0;
            while (j < num_pages) : (j += 1) {
                pmm.free_page(buffer.phys_pages[j]);
            }
        }

        while (i < num_pages) : (i += 1) {
            const virt_addr = buffer.virt_base + (i * PAGE_SIZE);
            const phys_addr = buffer.phys_pages[i];

            try paging.map_page(virt_addr, phys_addr, paging.PAGE_WRITABLE);

            const zero_ptr: [*]volatile u8 = @ptrFromInt(phys_addr + HIGHER_HALF);
            for (0..PAGE_SIZE) |j| {
                zero_ptr[j] = 0;
            }
        }

        const data_ptr: [*]u8 = @ptrFromInt(buffer.virt_base);
        buffer.data = data_ptr[0..size];

        return buffer;
    }

    pub fn free(self: *VirtualBuffer) void {
        for (0..self.num_pages) |i| {
            pmm.free_page(self.phys_pages[i]);
        }
    }
};

pub fn setup(kata: *types.Kata, framebuffer_phys: u64, framebuffer_size: u64) !void {
    kata.page_table = try paging.create_page_table();

    kata.user_stack_top = memory_const.USER_STACK_TOP;
    kata.user_stack_bottom = memory_const.USER_STACK_TOP - (memory_const.USER_STACK_MAX_PAGES * PAGE_SIZE);
    kata.user_stack_committed = memory_const.USER_STACK_TOP - (memory_const.USER_STACK_INITIAL_PAGES * PAGE_SIZE);

    const serial = @import("../drivers/serial/serial.zig");

    for (0..memory_const.USER_STACK_INITIAL_PAGES) |i| {
        const page = pmm.alloc_page() orelse return error.OutOfMemory;

        // Check if we got Ash's PD
        if (pmm.ash_pd_phys != 0 and page == pmm.ash_pd_phys) {
            serial.printf("SETUP: Got Ash's PD {x} for user stack page!\n", .{page});
        }

        const virt = kata.user_stack_committed + (i * PAGE_SIZE);
        _ = try paging.map_page_in_table(kata.page_table, virt, page, paging.PAGE_WRITABLE | paging.PAGE_USER);

        const page_ptr: [*]volatile u8 = @ptrFromInt(page + HIGHER_HALF);
        for (0..PAGE_SIZE) |j| {
            page_ptr[j] = 0;
        }
    }

    const first_page = pmm.alloc_page() orelse return error.OutOfMemory;

    // Check if we got Ash's PD for kernel stack
    if (pmm.ash_pd_phys != 0 and first_page == pmm.ash_pd_phys) {
        serial.printf("SETUP: Got Ash's PD {x} for kernel stack!\n", .{first_page});
    }

    const kernel_stack_base = first_page;

    // Identity map first page
    _ = try paging.map_page_in_table(kata.page_table, first_page, first_page, paging.PAGE_WRITABLE);

    // Zero the page
    var page_ptr: [*]volatile u8 = @ptrFromInt(first_page + HIGHER_HALF);
    for (0..PAGE_SIZE) |j| {
        page_ptr[j] = 0;
    }

    // Allocate remaining pages, checking for contiguity
    var i: u64 = 1;
    while (i < memory_const.KERNEL_STACK_PAGES) : (i += 1) {
        const page = pmm.alloc_page() orelse return error.OutOfMemory;
        const expected = first_page + (i * PAGE_SIZE);

        if (page != expected) {
            // Non-contiguous - free what we got and use smaller stack
            pmm.free_page(page);
            break;
        }

        // Identity map this page
        _ = try paging.map_page_in_table(kata.page_table, page, page, paging.PAGE_WRITABLE);

        // Zero the page
        page_ptr = @ptrFromInt(page + HIGHER_HALF);
        for (0..PAGE_SIZE) |j| {
            page_ptr[j] = 0;
        }
    }

    // Stack top is at the end of allocated contiguous pages (identity address)
    const actual_stack_size = i * PAGE_SIZE;
    kata.stack_top = kernel_stack_base + actual_stack_size;

    if (framebuffer_phys != 0 and framebuffer_size > 0) {
        const fb_pages = (framebuffer_size + PAGE_SIZE - 1) / PAGE_SIZE;
        for (0..fb_pages) |fi| {
            const phys = framebuffer_phys + (fi * PAGE_SIZE);
            _ = try paging.map_page_in_table(
                kata.page_table,
                phys,
                phys,
                paging.PAGE_WRITABLE | paging.PAGE_USER,
            );
        }
    }
}

pub fn load_segment(
    kata: *types.Kata,
    vaddr: u64,
    elf_data: []const u8,
    data_offset: u64,
    data_size: u64,
    mem_size: u64,
    flags: u32,
) !void {
    if (mem_size == 0) return;
    if (data_size > mem_size) return error.InvalidSegment;
    if (data_offset + data_size > elf_data.len) return error.SegmentOutOfBounds;

    if (!memory_limits.is_kata_range(vaddr, mem_size)) {
        return error.InvalidAddress;
    }

    const page_aligned_vaddr = vaddr & ~@as(u64, 0xFFF);
    const offset_in_page = vaddr - page_aligned_vaddr;

    const total_size = offset_in_page + mem_size;
    const num_pages = (total_size + PAGE_SIZE - 1) / PAGE_SIZE;

    var page_flags: u64 = paging.PAGE_USER;
    if ((flags & 0x2) != 0) {
        page_flags |= paging.PAGE_WRITABLE;
    }

    for (0..num_pages) |i| {
        const page_vaddr = page_aligned_vaddr + (i * PAGE_SIZE);

        var page_phys: u64 = 0;
        const existing_entry = paging.get_page_entry(kata.page_table, page_vaddr);

        if (existing_entry != null and (existing_entry.? & paging.PAGE_PRESENT) != 0) {
            page_phys = existing_entry.? & ~@as(u64, 0xFFF);

            const existing_writable = (existing_entry.? & paging.PAGE_WRITABLE) != 0;
            const new_writable = (page_flags & paging.PAGE_WRITABLE) != 0;

            if (new_writable and !existing_writable) {
                _ = try paging.map_page_in_table(kata.page_table, page_vaddr, page_phys, page_flags);
            }
        } else {
            page_phys = pmm.alloc_page() orelse return error.OutOfMemory;

            // Check if we got Ash's PD
            if (pmm.ash_pd_phys != 0 and page_phys == pmm.ash_pd_phys) {
                const serial = @import("../drivers/serial/serial.zig");
                serial.printf("KATA-MEM: Got Ash's PD {x} for data page at vaddr {x}!\n", .{ page_phys, page_vaddr });
            }

            _ = try paging.map_page_in_table(kata.page_table, page_vaddr, page_phys, page_flags);

            const zero_ptr: [*]volatile u8 = @ptrFromInt(page_phys + HIGHER_HALF);
            for (0..PAGE_SIZE) |j| {
                zero_ptr[j] = 0;
            }
        }

        const dest_ptr: [*]volatile u8 = @ptrFromInt(page_phys + HIGHER_HALF);

        const page_offset = if (i == 0) offset_in_page else 0;
        const segment_pos: u64 = if (i == 0) 0 else (i * PAGE_SIZE - offset_in_page);

        if (segment_pos < data_size) {
            const bytes_remaining = data_size - segment_pos;
            const bytes_to_copy = @min(PAGE_SIZE - page_offset, bytes_remaining);
            const elf_pos = data_offset + segment_pos;

            if (elf_pos + bytes_to_copy <= elf_data.len) {
                const src = elf_data[elf_pos .. elf_pos + bytes_to_copy];

                for (0..bytes_to_copy) |k| {
                    dest_ptr[page_offset + k] = src[k];
                }
            }
        }
    }
}

pub fn cleanup(kata: *types.Kata) void {
    if (kata.page_table != 0) {
        const current_cr3 = asm_memory.read_page_table_base();
        if (current_cr3 != kata.page_table) {
            paging.destroy_page_table(kata.page_table);
            kata.page_table = 0;
        }
        // If CR3 == kata.page_table, leave page_table intact for Shinigami
    }
    kata.stack_top = 0;
    kata.user_stack_top = 0;
    kata.user_stack_bottom = 0;
    kata.user_stack_committed = 0;
}

/// Called by Shinigami to destroy a zombie's page table.
/// Safe because Shinigami runs with its own page table.
pub fn destroy_zombie_page_table(page_table: u64) void {
    paging.destroy_page_table(page_table);
}

pub fn grow_stack(kata: *types.Kata, fault_addr: u64) bool {
    const page_addr = fault_addr & ~@as(u64, 0xFFF);

    if (page_addr >= kata.user_stack_committed or page_addr < kata.user_stack_bottom) {
        return false;
    }

    var addr = kata.user_stack_committed - PAGE_SIZE;
    while (addr >= page_addr) : (addr -= PAGE_SIZE) {
        const page = pmm.alloc_page() orelse return false;
        _ = paging.map_page_in_table(kata.page_table, addr, page, paging.PAGE_WRITABLE | paging.PAGE_USER) catch return false;

        const page_ptr: [*]volatile u8 = @ptrFromInt(page + HIGHER_HALF);
        for (0..PAGE_SIZE) |j| {
            page_ptr[j] = 0;
        }

        asm_memory.invalidate_page(addr);

        if (addr == 0) break;
    }

    kata.user_stack_committed = page_addr;
    return true;
}
