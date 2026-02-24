//! Kernel Heap Allocator

const heap_const = @import("../common/constants/heap.zig");
const memory_const = @import("../common/constants/memory.zig");
const pmm = @import("pmm.zig");
const serial = @import("../drivers/serial/serial.zig");

const PAGE_SIZE = memory_const.PAGE_SIZE;
const HIGHER_HALF = memory_const.HIGHER_HALF_START;

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

var caches: [heap_const.NUM_CACHES]SlabCache = undefined;
var initialized: bool = false;

pub fn init() void {
    serial.print("\n=== Heap ===\n");

    for (0..heap_const.NUM_CACHES) |i| {
        const size = heap_const.SIZE_CLASSES[i];
        const usable_space = PAGE_SIZE - @sizeOf(SlabHeader);
        const objects_per_slab = usable_space / size;

        caches[i] = SlabCache{
            .object_size = size,
            .objects_per_slab = objects_per_slab,
            .slab_list = null,
        };

        serial.printf("Cache {}B: {} objects/slab\n", .{ size, objects_per_slab });
    }

    initialized = true;
    serial.print("Heap ready\n");
}

pub fn alloc(size: usize) ?[*]u8 {
    if (!initialized) return null;
    if (size == 0) return null;

    if (size > heap_const.LARGE_ALLOC_THRESHOLD) {
        return alloc_large(size);
    }

    const cache_idx = find_cache_index(size);
    return alloc_from_cache(&caches[cache_idx]);
}

pub fn free(ptr: [*]u8, size: usize) void {
    if (!initialized) return;
    if (size == 0) return;

    if (size > heap_const.LARGE_ALLOC_THRESHOLD) {
        free_large(ptr, size);
        return;
    }

    const cache_idx = find_cache_index(size);
    free_to_cache(&caches[cache_idx], ptr);
}

fn find_cache_index(size: usize) usize {
    for (0..heap_const.NUM_CACHES) |i| {
        if (size <= heap_const.SIZE_CLASSES[i]) {
            return i;
        }
    }
    return heap_const.NUM_CACHES - 1;
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
    const virt_addr = phys_page + HIGHER_HALF;

    const page_ptr: [*]volatile u8 = @ptrFromInt(virt_addr);
    for (0..PAGE_SIZE) |i| {
        page_ptr[i] = 0;
    }

    const slab: *SlabHeader = @ptrFromInt(virt_addr);
    slab.free_count = cache.objects_per_slab;
    slab.total_count = cache.objects_per_slab;
    slab.object_size = cache.object_size;
    slab.next_slab = null;
    slab.prev_slab = null;

    const first_obj_addr = virt_addr + @sizeOf(SlabHeader);
    for (0..cache.objects_per_slab) |j| {
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

    if (slab.free_count == slab.total_count) {
        if (slab.next_slab != null or slab.prev_slab != null) {
            return_slab_to_pmm(cache, slab);
        }
    }
}

fn return_slab_to_pmm(cache: *SlabCache, slab: *SlabHeader) void {
    if (slab.prev_slab) |prev| {
        prev.next_slab = slab.next_slab;
    } else {
        cache.slab_list = slab.next_slab;
    }

    if (slab.next_slab) |next| {
        next.prev_slab = slab.prev_slab;
    }

    const slab_addr = @intFromPtr(slab);
    const phys_addr = slab_addr - HIGHER_HALF;
    pmm.free_page(phys_addr);
}

fn alloc_large(size: usize) ?[*]u8 {
    const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;

    var pages: [heap_const.MAX_LARGE_PAGES]u64 = undefined;
    if (num_pages > heap_const.MAX_LARGE_PAGES) return null;

    for (0..num_pages) |i| {
        pages[i] = pmm.alloc_page() orelse {
            for (0..i) |j| {
                pmm.free_page(pages[j]);
            }
            return null;
        };
    }

    const result: [*]u8 = @ptrFromInt(pages[0] + HIGHER_HALF);
    return result;
}

fn free_large(ptr: [*]u8, size: usize) void {
    const num_pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
    const base_virt = @intFromPtr(ptr);
    const base_phys = base_virt - HIGHER_HALF;

    for (0..num_pages) |i| {
        pmm.free_page(base_phys + (i * PAGE_SIZE));
    }
}
