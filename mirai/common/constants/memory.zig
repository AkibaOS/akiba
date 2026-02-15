//! Memory constants

pub const PAGE_SIZE: u64 = 4096;
pub const PAGE_OFFSET_MASK: u64 = 0xFFF;
pub const PAGE_FRAME_MASK: u64 = ~PAGE_OFFSET_MASK;

pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;
pub const MIRAI_PHYSICAL_START: u64 = 0x100000;
pub const MIRAI_PHYSICAL_END: u64 = 0x500000;
pub const MIRAI_VIRTUAL_START: u64 = HIGHER_HALF_START + MIRAI_PHYSICAL_START;

extern const _kernel_end: u8;

pub fn MIRAI_END() u64 {
    const link_addr = @intFromPtr(&_kernel_end);
    if (link_addr >= HIGHER_HALF_START) {
        return link_addr - HIGHER_HALF_START;
    } else {
        return link_addr;
    }
}

pub const KATA_SPACE_START: u64 = 0x1000;
pub const KATA_SPACE_END: u64 = 0x0000800000000000;

pub const PTE_PRESENT: u64 = 1 << 0;
pub const PTE_WRITABLE: u64 = 1 << 1;
pub const PTE_USER: u64 = 1 << 2;
pub const PTE_WRITE_THROUGH: u64 = 1 << 3;
pub const PTE_CACHE_DISABLE: u64 = 1 << 4;
pub const PTE_ACCESSED: u64 = 1 << 5;
pub const PTE_DIRTY: u64 = 1 << 6;
pub const PTE_HUGE_PAGE: u64 = 1 << 7;
pub const PTE_GLOBAL: u64 = 1 << 8;
pub const PTE_NO_EXECUTE: u64 = 1 << 63;

pub const PAGE_TABLE_ENTRIES: usize = 512;
pub const PML4_SHIFT: u6 = 39;
pub const PDPT_SHIFT: u6 = 30;
pub const PD_SHIFT: u6 = 21;
pub const PT_SHIFT: u6 = 12;
pub const TABLE_INDEX_MASK: u64 = 0x1FF;

pub inline fn align_down(addr: u64) u64 {
    return addr & PAGE_FRAME_MASK;
}

pub inline fn align_up(addr: u64) u64 {
    return (addr + PAGE_SIZE - 1) & PAGE_FRAME_MASK;
}

pub inline fn pages_for_size(size: u64) u64 {
    return (size + PAGE_SIZE - 1) / PAGE_SIZE;
}

pub inline fn is_page_aligned(addr: u64) bool {
    return (addr & PAGE_OFFSET_MASK) == 0;
}

pub inline fn pml4_index(vaddr: u64) u64 {
    return (vaddr >> PML4_SHIFT) & TABLE_INDEX_MASK;
}

pub inline fn pdpt_index(vaddr: u64) u64 {
    return (vaddr >> PDPT_SHIFT) & TABLE_INDEX_MASK;
}

pub inline fn pd_index(vaddr: u64) u64 {
    return (vaddr >> PD_SHIFT) & TABLE_INDEX_MASK;
}

pub inline fn pt_index(vaddr: u64) u64 {
    return (vaddr >> PT_SHIFT) & TABLE_INDEX_MASK;
}

pub inline fn virt_to_phys(vaddr: u64) u64 {
    return vaddr - HIGHER_HALF_START;
}

pub inline fn phys_to_virt(paddr: u64) u64 {
    return paddr + HIGHER_HALF_START;
}
