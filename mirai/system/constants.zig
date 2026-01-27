//! System Constants - Memory layout, addresses, and architectural constants
//! This is the single source of truth for all memory-related and system-wide constants

// ============================================================================
// Page and Memory Block Sizes
// ============================================================================

/// Standard page size (4KB on x86-64)
pub const PAGE_SIZE: u64 = 4096;

/// Page offset mask (bits 0-11)
pub const PAGE_OFFSET_MASK: u64 = 0xFFF;

/// Page frame mask (clears offset bits)
pub const PAGE_FRAME_MASK: u64 = ~PAGE_OFFSET_MASK;

// ============================================================================
// Memory Address Space Layout
// ============================================================================

/// Higher-half kernel space start (canonical address boundary)
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

/// Kernel physical start address (loaded at 1MB)
pub const KERNEL_PHYSICAL_START: u64 = 0x100000;

/// Kernel physical end address
pub const KERNEL_PHYSICAL_END: u64 = 0x500000;

/// Virtual address where kernel is mapped
pub const KERNEL_VIRTUAL_START: u64 = HIGHER_HALF_START + KERNEL_PHYSICAL_START;

/// External linker symbol marking the end of the kernel binary
extern const _kernel_end: u8;

/// Dynamically calculate the physical address where kernel binary ends
/// The linker places _kernel_end at the end of .bss section
/// This symbol's address is in the linker's address space (starts at 0x100000)
pub fn KERNEL_END() u64 {
    // Get the link-time address of the symbol
    const link_addr = @intFromPtr(&_kernel_end);
    // The linker script starts at 0x100000, so this is already a physical address
    // but we need to handle if it's in higher-half or identity mapping
    if (link_addr >= HIGHER_HALF_START) {
        // Symbol accessed through higher-half mapping, convert to physical
        return link_addr - HIGHER_HALF_START;
    } else {
        // Symbol accessed through identity mapping or direct physical address
        return link_addr;
    }
}

// ============================================================================
// User Address Space Layout
// ============================================================================

/// Userspace virtual address start (first valid page after null page)
pub const USER_SPACE_START: u64 = 0x1000;

/// Userspace virtual address maximum (canonical address boundary)
pub const USER_SPACE_END: u64 = 0x0000800000000000;

// ============================================================================
// Stack Configuration
// ============================================================================

/// User stack top address (grows downward)
pub const USER_STACK_TOP: u64 = 0x00007FFFFFF00000;

/// Number of pages allocated for user stack
pub const USER_STACK_PAGES: u64 = 64; // 256KB

/// Total user stack size in bytes
pub const USER_STACK_SIZE: u64 = USER_STACK_PAGES * PAGE_SIZE;

/// Kernel stack size per process (one page)
pub const KERNEL_STACK_SIZE: u64 = PAGE_SIZE;

// ============================================================================
// Page Table Entry Flags
// ============================================================================

/// Page is present in memory
pub const PTE_PRESENT: u64 = 1 << 0;

/// Page is writable
pub const PTE_WRITABLE: u64 = 1 << 1;

/// Page is accessible from user mode
pub const PTE_USER: u64 = 1 << 2;

/// Page has write-through caching
pub const PTE_WRITE_THROUGH: u64 = 1 << 3;

/// Page caching is disabled
pub const PTE_CACHE_DISABLE: u64 = 1 << 4;

/// Page has been accessed
pub const PTE_ACCESSED: u64 = 1 << 5;

/// Page has been written to
pub const PTE_DIRTY: u64 = 1 << 6;

/// Page is a huge page (2MB or 1GB)
pub const PTE_HUGE_PAGE: u64 = 1 << 7;

/// Page is global (not flushed on CR3 reload)
pub const PTE_GLOBAL: u64 = 1 << 8;

/// Execute disable bit
pub const PTE_NO_EXECUTE: u64 = 1 << 63;

// ============================================================================
// Page Table Structure
// ============================================================================

/// Number of entries in each page table level
pub const PAGE_TABLE_ENTRIES: usize = 512;

/// Shift for PML4 index (bits 39-47)
pub const PML4_SHIFT: u6 = 39;

/// Shift for PDPT index (bits 30-38)
pub const PDPT_SHIFT: u6 = 30;

/// Shift for PD index (bits 21-29)
pub const PD_SHIFT: u6 = 21;

/// Shift for PT index (bits 12-20)
pub const PT_SHIFT: u6 = 12;

/// Mask for table indices (9 bits = 512 entries)
pub const TABLE_INDEX_MASK: u64 = 0x1FF;

// ============================================================================
// Interrupt and Exception Vectors
// ============================================================================

/// Divide by zero exception
pub const EXCEPTION_DIVIDE_ERROR: u8 = 0;

/// Debug exception
pub const EXCEPTION_DEBUG: u8 = 1;

/// Non-maskable interrupt
pub const EXCEPTION_NMI: u8 = 2;

/// Breakpoint exception
pub const EXCEPTION_BREAKPOINT: u8 = 3;

/// Overflow exception
pub const EXCEPTION_OVERFLOW: u8 = 4;

/// Bound range exceeded
pub const EXCEPTION_BOUND_RANGE: u8 = 5;

/// Invalid opcode
pub const EXCEPTION_INVALID_OPCODE: u8 = 6;

/// Device not available
pub const EXCEPTION_DEVICE_NOT_AVAILABLE: u8 = 7;

/// Double fault
pub const EXCEPTION_DOUBLE_FAULT: u8 = 8;

/// Invalid TSS
pub const EXCEPTION_INVALID_TSS: u8 = 10;

/// Segment not present
pub const EXCEPTION_SEGMENT_NOT_PRESENT: u8 = 11;

/// Stack-segment fault
pub const EXCEPTION_STACK_FAULT: u8 = 12;

/// General protection fault
pub const EXCEPTION_GENERAL_PROTECTION: u8 = 13;

/// Page fault
pub const EXCEPTION_PAGE_FAULT: u8 = 14;

/// x87 FPU error
pub const EXCEPTION_FPU_ERROR: u8 = 16;

/// Alignment check
pub const EXCEPTION_ALIGNMENT_CHECK: u8 = 17;

/// Machine check
pub const EXCEPTION_MACHINE_CHECK: u8 = 18;

/// SIMD floating-point exception
pub const EXCEPTION_SIMD_EXCEPTION: u8 = 19;

/// Timer interrupt vector (IRQ 0)
pub const IRQ_TIMER: u8 = 32;

/// Keyboard interrupt vector (IRQ 1)
pub const IRQ_KEYBOARD: u8 = 33;

/// Syscall interrupt vector
pub const INTERRUPT_SYSCALL: u8 = 0x80;

// ============================================================================
// Timing Constants
// ============================================================================

/// Timer tick frequency (nanoseconds per tick)
pub const TIMER_TICK_NS: u64 = 1_000_000; // 1ms

/// Scheduler time slice (in timer ticks)
pub const SCHEDULER_TIME_SLICE: u64 = 10; // 10ms

// ============================================================================
// Sector and Block Sizes
// ============================================================================

/// Standard disk sector size
pub const SECTOR_SIZE: usize = 512;

/// Standard cluster size for filesystem
pub const CLUSTER_SIZE: usize = 4096;

// ============================================================================
// Helper Functions
// ============================================================================

/// Align address down to page boundary
pub inline fn align_down(addr: u64) u64 {
    return addr & PAGE_FRAME_MASK;
}

/// Align address up to page boundary
pub inline fn align_up(addr: u64) u64 {
    return (addr + PAGE_SIZE - 1) & PAGE_FRAME_MASK;
}

/// Calculate number of pages needed for given size
pub inline fn pages_for_size(size: u64) u64 {
    return (size + PAGE_SIZE - 1) / PAGE_SIZE;
}

/// Check if address is page-aligned
pub inline fn is_page_aligned(addr: u64) bool {
    return (addr & PAGE_OFFSET_MASK) == 0;
}

/// Extract PML4 index from virtual address
pub inline fn pml4_index(vaddr: u64) u64 {
    return (vaddr >> PML4_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PDPT index from virtual address
pub inline fn pdpt_index(vaddr: u64) u64 {
    return (vaddr >> PDPT_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PD index from virtual address
pub inline fn pd_index(vaddr: u64) u64 {
    return (vaddr >> PD_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PT index from virtual address
pub inline fn pt_index(vaddr: u64) u64 {
    return (vaddr >> PT_SHIFT) & TABLE_INDEX_MASK;
}

/// Get physical address from higher-half virtual address
pub inline fn virt_to_phys(vaddr: u64) u64 {
    return vaddr - HIGHER_HALF_START;
}

/// Get higher-half virtual address from physical address
pub inline fn phys_to_virt(paddr: u64) u64 {
    return paddr + HIGHER_HALF_START;
}
