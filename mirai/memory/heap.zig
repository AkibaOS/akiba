//! Kernel Heap Allocator
//! Size-segregated allocator with object caching

const serial = @import("../drivers/serial.zig");
const pmm = @import("pmm.zig");

const PAGE_SIZE: usize = 4096;
const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

const SIZE_CLASSES = [_]usize{ 16, 32, 64, 128, 256, 512, 1024, 2048 };
const NUM_CACHES = SIZE_CLASSES.len;

const SlabHeader = struct {
    free_count: usize,
    total_count: usize,
    object_size: usize,
    next_slab: ?*SlabHeader,
    prev_slab: ?*SlabHeader,
    first_free: ?*FreeObject,
};

const FreeObject = struct {
    next: ?*FreeObject,
};

const SlabCache = struct {
    object_size: usize,
    objects_per_slab: usize,
    slab_list: ?*SlabHeader,
};

var caches: [NUM_CACHES]SlabCache = undefined;
var initialized: bool = false;

pub fn init() void {
    serial.print("\n=== Heap Allocator ===\n");

    var i: usize = 0;
    while (i < NUM_CACHES) : (i += 1) {
        const size = SIZE_CLASSES[i];
        const usable_space = PAGE_SIZE - @sizeOf(SlabHeader);
        const objects_per_slab = usable_space / size;

        caches[i] = SlabCache{
            .object_size = size,
            .objects_per_slab = objects_per_slab,
            .slab_list = null,
        };

        serial.print("  Cache ");
        serial.print_hex(size);
        serial.print("B: ");
        serial.print_hex(objects_per_slab);
        serial.print(" objects/slab\n");
    }

    initialized = true;
    serial.print("Heap ready\n");
}

pub fn alloc(size: usize) ?[*]u8 {
    if (!initialized) return null;
    if (size == 0) return null;

    if (size > 2048) {
        return alloc_large(size);
    }

    const cache_idx = find_cache_index(size);
    return alloc_from_cache(&caches[cache_idx]);
}

pub fn free(ptr: [*]u8, size: usize) void {
    if (!initialized) return;
    if (size == 0) return;

    if (size > 2048) {
        free_large(ptr, size);
        return;
    }

    const cache_idx = find_cache_index(size);
    free_to_cache(&caches[cache_idx], ptr);
}

fn find_cache_index(size: usize) usize {
    var i: usize = 0;
    while (i < NUM_CACHES) : (i += 1) {
        if (size <= SIZE_CLASSES[i]) {
            return i;
        }
    }
    return NUM_CACHES - 1;
}

fn alloc_from_cache(cache: *SlabCache) ?[*]u8 {
    var current_slab = cache.slab_list;
    while (current_slab) |slab| {
        if (slab.free_count > 0) {
            return alloc_from_slab(slab);
        }
        current_slab = slab.next_slab;
    }

    const new_slab = create_slab(cache) orelse return null;
    new_slab.next_slab = cache.slab_list;
    new_slab.prev_slab = null;

    if (cache.slab_list) |first| {
        first.prev_slab = new_slab;
    }

    cache.slab_list = new_slab;

    return alloc_from_slab(new_slab);
}

fn create_slab(cache: *SlabCache) ?*SlabHeader {
    const phys_page = pmm.alloc_page() orelse return null;

    // Physical 0-4GB already mapped to 0xFFFF800000000000+ by boot.s
    const virt_addr = phys_page + HIGHER_HALF_START;

    // Zero the page
    const page_ptr: [*]volatile u8 = @ptrFromInt(virt_addr);
    var i: usize = 0;
    while (i < PAGE_SIZE) : (i += 1) {
        page_ptr[i] = 0;
    }

    const slab: *SlabHeader = @ptrFromInt(virt_addr);
    slab.free_count = cache.objects_per_slab;
    slab.total_count = cache.objects_per_slab;
    slab.object_size = cache.object_size;
    slab.next_slab = null;
    slab.prev_slab = null;

    // Initialize freelist
    const first_obj_addr = virt_addr + @sizeOf(SlabHeader);
    var j: usize = 0;
    while (j < cache.objects_per_slab) : (j += 1) {
        const obj_addr = first_obj_addr + (j * cache.object_size);
        const obj: *FreeObject = @ptrFromInt(obj_addr);

        if (j + 1 < cache.objects_per_slab) {
            const next_addr = obj_addr + cache.object_size;
            obj.next = @ptrFromInt(next_addr);
        } else {
            obj.next = null;
        }
    }

    slab.first_free = @ptrFromInt(first_obj_addr);

    return slab;
}

fn alloc_from_slab(slab: *SlabHeader) ?[*]u8 {
    if (slab.first_free) |free_obj| {
        slab.first_free = free_obj.next;
        slab.free_count -= 1;

        return @ptrFromInt(@intFromPtr(free_obj));
    }

    return null;
}

fn free_to_cache(cache: *SlabCache, ptr: [*]u8) void {
    const ptr_addr = @intFromPtr(ptr);
    const slab_addr = ptr_addr & ~@as(u64, PAGE_SIZE - 1);
    const slab: *SlabHeader = @ptrFromInt(slab_addr);

    const obj: *FreeObject = @ptrFromInt(ptr_addr);
    obj.next = slab.first_free;
    slab.first_free = obj;
    slab.free_count += 1;

    // If slab is completely free and not the only slab, return to PMM
    if (slab.free_count == slab.total_count) {
        if (slab.next_slab != null or slab.prev_slab != null) {
            return_slab_to_pmm(cache, slab);
        }
    }
}

fn return_slab_to_pmm(cache: *SlabCache, slab: *SlabHeader) void {
    // Unlink from cache
    if (slab.prev_slab) |prev| {
        prev.next_slab = slab.next_slab;
    } else {
        cache.slab_list = slab.next_slab;
    }

    if (slab.next_slab) |next| {
        next.prev_slab = slab.prev_slab;
    }

    // Free the page
    const slab_addr = @intFromPtr(slab);
    const phys_addr = slab_addr - HIGHER_HALF_START;
    pmm.free_page(phys_addr);
}

fn alloc_large(size: usize) ?[*]u8 {
    const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;

    // Try to allocate contiguous pages
    var pages: [64]u64 = undefined; // Max 256KB allocation
    if (num_pages > 64) return null;

    var i: usize = 0;
    while (i < num_pages) : (i += 1) {
        pages[i] = pmm.alloc_page() orelse {
            // Allocation failed - free what we got
            var j: usize = 0;
            while (j < i) : (j += 1) {
                pmm.free_page(pages[j]);
            }
            return null;
        };
    }

    // Return first page as virtual address
    const result: [*]u8 = @ptrFromInt(pages[0] + HIGHER_HALF_START);
    return result;
}

fn free_large(ptr: [*]u8, size: usize) void {
    const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
    const base_virt = @intFromPtr(ptr);
    const base_phys = base_virt - HIGHER_HALF_START;

    // Free each page
    var i: usize = 0;
    while (i < num_pages) : (i += 1) {
        pmm.free_page(base_phys + (i * PAGE_SIZE));
    }
}

pub fn print_stats() void {
    if (!initialized) {
        serial.print("Heap not initialized\n");
        return;
    }

    serial.print("\n=== Heap Statistics ===\n");

    var total_slabs: usize = 0;
    var total_used: usize = 0;
    var total_free: usize = 0;

    var i: usize = 0;
    while (i < NUM_CACHES) : (i += 1) {
        const cache = &caches[i];

        var cache_total: usize = 0;
        var cache_free: usize = 0;
        var slab_count: usize = 0;

        var current = cache.slab_list;
        while (current) |slab| {
            slab_count += 1;
            cache_total += slab.total_count;
            cache_free += slab.free_count;
            current = slab.next_slab;
        }

        if (slab_count > 0) {
            const used = cache_total - cache_free;
            total_slabs += slab_count;
            total_used += used * cache.object_size;
            total_free += cache_free * cache.object_size;

            serial.print("Cache ");
            serial.print_hex(cache.object_size);
            serial.print("B: ");
            serial.print_hex(slab_count);
            serial.print(" slabs, ");
            serial.print_hex(used);
            serial.print("/");
            serial.print_hex(cache_total);
            serial.print(" objects\n");
        }
    }

    serial.print("\nTotal: ");
    serial.print_hex(total_slabs);
    serial.print(" slabs, ");
    serial.print_hex(total_used);
    serial.print(" bytes used, ");
    serial.print_hex(total_free);
    serial.print(" bytes free\n");
}
