//! Page Table Manager - Dynamic page table manipulation for hybrid kernel

const serial = @import("../drivers/serial.zig");
const pmm = @import("pmm.zig");

pub const PAGE_SIZE: u64 = 4096;
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

const PAGE_PRESENT: u64 = 1 << 0;
const PAGE_WRITABLE: u64 = 1 << 1;
const PAGE_USER: u64 = 1 << 2;

fn get_cr3() u64 {
    return asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (-> u64),
    );
}

fn invlpg(addr: u64) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true }
    );
}

pub fn map_page(virt: u64, phys: u64, flags: u64) !void {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    // CR3 points to PML4 physical address
    const pml4_phys = get_cr3() & ~@as(u64, 0xFFF);
    // Access it via higher-half mapping
    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys + HIGHER_HALF_START);

    // Get or create PDPT
    var pdpt_phys: u64 = undefined;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pdpt_phys + HIGHER_HALF_START);
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pdpt_phys = pml4[pml4_index] & ~@as(u64, 0xFFF);
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    // Get or create PD
    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pd_phys = pdpt[pdpt_index] & ~@as(u64, 0xFFF);
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    // Get or create PT
    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pt_phys + HIGHER_HALF_START);
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pt_phys = pd[pd_index] & ~@as(u64, 0xFFF);
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    // Map the page
    pt[pt_index] = phys | PAGE_PRESENT | PAGE_WRITABLE | flags;

    invlpg(virt);
}

fn zero_page(virt: u64) void {
    const ptr: [*]volatile u8 = @ptrFromInt(virt);
    var i: usize = 0;
    while (i < PAGE_SIZE) : (i += 1) {
        ptr[i] = 0;
    }
}

pub fn init() void {
    serial.print("\n=== Page Table Manager ===\n");
    serial.print("CR3: ");
    serial.print_hex(get_cr3());
    serial.print("\n");
}
