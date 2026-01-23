//! Kata Memory Management - Memory setup and allocation for kata processes
//! Handles page table creation, stack allocation, segment mapping, and virtual buffers

const constants = @import("../memory/constants.zig");
const kata_mod = @import("kata.zig");
const paging = @import("../memory/paging.zig");
const pmm = @import("../memory/pmm.zig");
const serial = @import("../drivers/serial.zig");

const HIGHER_HALF = constants.HIGHER_HALF_START;
const PAGE_SIZE = constants.PAGE_SIZE;
const USER_STACK_TOP = constants.USER_STACK_TOP;
const USER_STACK_PAGES = constants.USER_STACK_PAGES;
const KERNEL_STACK_SIZE = constants.KERNEL_STACK_SIZE;

// Virtual address range for large kernel allocations (use highest PML4 entry to avoid conflicts)
const KERNEL_VMALLOC_START: u64 = 0xFFFFFF8000000000; // PML4[0x1FF] - last PML4 entry
var next_vmalloc_addr: u64 = KERNEL_VMALLOC_START;

/// Virtual buffer allocation - properly maps scattered physical pages into contiguous virtual space
pub const VirtualBuffer = struct {
    data: []u8,
    virt_base: u64,
    phys_pages: [1024]u64,
    num_pages: usize,

    /// Allocate a large contiguous virtual buffer backed by potentially scattered physical pages
    /// NOTE: This can interfere with MMIO due to TLB/cache behavior when creating new page tables.
    /// For temporary allocations, prefer using scattered pages via higher-half instead.
    pub fn alloc(size: usize) !VirtualBuffer {
        const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
        if (num_pages > 1024) return error.AllocationTooLarge;

        var buffer: VirtualBuffer = undefined;
        buffer.num_pages = num_pages;

        // Allocate physical pages (can be non-contiguous)
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

        // Allocate contiguous virtual address space
        buffer.virt_base = next_vmalloc_addr;
        next_vmalloc_addr += num_pages * PAGE_SIZE;

        // Map each physical page to its corresponding virtual address
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

            // Zero the page via higher-half direct mapping for efficiency
            const zero_ptr: [*]volatile u8 = @ptrFromInt(phys_addr + HIGHER_HALF);
            var j: usize = 0;
            while (j < PAGE_SIZE) : (j += 1) {
                zero_ptr[j] = 0;
            }
        }

        const data_ptr: [*]u8 = @ptrFromInt(buffer.virt_base);
        buffer.data = data_ptr[0..size];

        return buffer;
    }

    /// Free the virtual buffer and all associated physical pages
    pub fn free(self: *VirtualBuffer) void {
        // Free physical pages
        var i: usize = 0;
        while (i < self.num_pages) : (i += 1) {
            pmm.free_page(self.phys_pages[i]);
        }

        // Note: We don't unmap the virtual addresses to avoid fragmentation
        // in the vmalloc region. In a production OS, we'd have a proper
        // virtual address space allocator that could reclaim this space.
    }
};

/// Setup kata memory including page table, stacks, and framebuffer
pub fn setup_kata_memory(kata: *kata_mod.Kata, framebuffer_phys: u64, framebuffer_size: u64) !void {
    // Create independent page table
    kata.page_table = try paging.create_page_table();

    // Setup user stack
    const user_stack_base = USER_STACK_TOP - (USER_STACK_PAGES * PAGE_SIZE);
    var i: usize = 0;
    while (i < USER_STACK_PAGES) : (i += 1) {
        const page = pmm.alloc_page() orelse return error.OutOfMemory;
        const virt = user_stack_base + (i * PAGE_SIZE);
        _ = try paging.map_page_in_table(kata.page_table, virt, page, paging.PAGE_WRITABLE | paging.PAGE_USER);

        // Zero the page
        const page_ptr: [*]volatile u8 = @ptrFromInt(page + HIGHER_HALF);
        var j: usize = 0;
        while (j < PAGE_SIZE) : (j += 1) {
            page_ptr[j] = 0;
        }
    }
    kata.user_stack_top = USER_STACK_TOP;

    // Setup kernel stack (4KB)
    const kernel_stack_page = pmm.alloc_page() orelse return error.OutOfMemory;
    kata.stack_top = kernel_stack_page + HIGHER_HALF + KERNEL_STACK_SIZE;

    // Identity map framebuffer for user access
    if (framebuffer_phys != 0 and framebuffer_size > 0) {
        const fb_pages = (framebuffer_size + PAGE_SIZE - 1) / PAGE_SIZE;
        i = 0;
        while (i < fb_pages) : (i += 1) {
            const phys = framebuffer_phys + (i * PAGE_SIZE);
            _ = try paging.map_page_in_table(
                kata.page_table,
                phys,
                phys,
                paging.PAGE_WRITABLE | paging.PAGE_USER,
            );
        }
    }
}

/// Load a segment into kata memory with proper page allocation and mapping
pub fn load_segment(
    kata: *kata_mod.Kata,
    vaddr: u64,
    file_data: []const u8,
    file_offset: u64,
    file_size: u64,
    mem_size: u64,
    flags: u32,
) !void {
    const page_aligned_vaddr = vaddr & ~@as(u64, 0xFFF);
    const offset_in_page = vaddr - page_aligned_vaddr;

    const total_size = offset_in_page + mem_size;
    const num_pages = (total_size + PAGE_SIZE - 1) / PAGE_SIZE;

    // Setup page flags
    var page_flags: u64 = paging.PAGE_USER;
    if ((flags & 0x2) != 0) { // Writable
        page_flags |= paging.PAGE_WRITABLE;
    }

    // Allocate and map pages
    var i: usize = 0;
    while (i < num_pages) : (i += 1) {
        const page_vaddr = page_aligned_vaddr + (i * PAGE_SIZE);

        // Check if page is already mapped (for overlapping segments)
        var page_phys: u64 = 0;
        const existing_entry = paging.get_page_entry(kata.page_table, page_vaddr);

        if (existing_entry != null and (existing_entry.? & paging.PAGE_PRESENT) != 0) {
            // Page already mapped, reuse it (don't zero!)
            page_phys = existing_entry.? & ~@as(u64, 0xFFF);

            // Always update to the most permissive flags (writable if any segment needs write)
            // This handles cases where .rodata and .bss share a page
            const existing_writable = (existing_entry.? & paging.PAGE_WRITABLE) != 0;
            const new_writable = (page_flags & paging.PAGE_WRITABLE) != 0;

            if (new_writable and !existing_writable) {
                // Need to upgrade to writable
                _ = try paging.map_page_in_table(kata.page_table, page_vaddr, page_phys, page_flags);
            }
        } else {
            // Allocate new page
            page_phys = pmm.alloc_page() orelse return error.OutOfMemory;
            _ = try paging.map_page_in_table(kata.page_table, page_vaddr, page_phys, page_flags);

            // Zero only new pages
            const zero_ptr: [*]volatile u8 = @ptrFromInt(page_phys + HIGHER_HALF);
            var j: usize = 0;
            while (j < PAGE_SIZE) : (j += 1) {
                zero_ptr[j] = 0;
            }
        }

        // Get pointer to physical page for data copying
        const dest_ptr: [*]volatile u8 = @ptrFromInt(page_phys + HIGHER_HALF);

        // Copy data if within file size
        // Calculate where in the destination page to start writing (only matters for first page)
        const page_offset = if (i == 0) offset_in_page else 0;

        // Calculate position in the source segment data
        // For first page: starts at 0
        // For subsequent pages: (i * PAGE_SIZE - offset_in_page)
        const segment_pos: u64 = if (i == 0) 0 else (i * PAGE_SIZE - offset_in_page);

        // Only copy if we haven't exceeded the file data
        if (segment_pos < file_size) {
            const bytes_remaining = file_size - segment_pos;
            const bytes_to_copy = @min(PAGE_SIZE - page_offset, bytes_remaining);
            const file_pos = file_offset + segment_pos;

            if (file_pos + bytes_to_copy <= file_data.len) {
                const src = file_data[file_pos .. file_pos + bytes_to_copy];

                var k: usize = 0;
                while (k < bytes_to_copy) : (k += 1) {
                    dest_ptr[page_offset + k] = src[k];
                }
            } else {
                serial.print("[LOAD_SEGMENT] ERROR: file_pos + bytes_to_copy > file_data.len\n");
            }
        }
    }
}
