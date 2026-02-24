//! Hikari Assembly Operations

pub inline fn read_cr3() u64 {
    return asm volatile ("mov %cr3, %[ret]"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn write_cr3(value: u64) void {
    asm volatile ("mov %[value], %cr3"
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub inline fn read_cr0() u64 {
    return asm volatile ("mov %cr0, %[ret]"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn write_cr0(value: u64) void {
    asm volatile ("mov %[value], %cr0"
        :
        : [value] "r" (value),
    );
}

pub inline fn read_cr4() u64 {
    return asm volatile ("mov %cr4, %[ret]"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn write_cr4(value: u64) void {
    asm volatile ("mov %[value], %cr4"
        :
        : [value] "r" (value),
    );
}

pub inline fn read_msr(msr: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [msr] "{ecx}" (msr),
    );
    return (@as(u64, high) << 32) | low;
}

pub inline fn write_msr(msr: u32, value: u64) void {
    const low: u32 = @truncate(value);
    const high: u32 = @truncate(value >> 32);
    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high),
    );
}

pub inline fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub inline fn disable_interrupts() void {
    asm volatile ("cli");
}

pub inline fn enable_interrupts() void {
    asm volatile ("sti");
}

pub inline fn invlpg(address: u64) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (address),
        : .{ .memory = true });
}

pub inline fn flush_tlb() void {
    const cr3 = read_cr3();
    write_cr3(cr3);
}

pub const msr_efer: u32 = 0xC0000080;
pub const efer_sce: u64 = 1 << 0;
pub const efer_lme: u64 = 1 << 8;
pub const efer_lma: u64 = 1 << 10;
pub const efer_nxe: u64 = 1 << 11;

pub const cr0_pe: u64 = 1 << 0;
pub const cr0_mp: u64 = 1 << 1;
pub const cr0_em: u64 = 1 << 2;
pub const cr0_ts: u64 = 1 << 3;
pub const cr0_et: u64 = 1 << 4;
pub const cr0_ne: u64 = 1 << 5;
pub const cr0_wp: u64 = 1 << 16;
pub const cr0_am: u64 = 1 << 18;
pub const cr0_nw: u64 = 1 << 29;
pub const cr0_cd: u64 = 1 << 30;
pub const cr0_pg: u64 = 1 << 31;

pub const cr4_vme: u64 = 1 << 0;
pub const cr4_pvi: u64 = 1 << 1;
pub const cr4_tsd: u64 = 1 << 2;
pub const cr4_de: u64 = 1 << 3;
pub const cr4_pse: u64 = 1 << 4;
pub const cr4_pae: u64 = 1 << 5;
pub const cr4_mce: u64 = 1 << 6;
pub const cr4_pge: u64 = 1 << 7;
pub const cr4_pce: u64 = 1 << 8;
pub const cr4_osfxsr: u64 = 1 << 9;
pub const cr4_osxmmexcpt: u64 = 1 << 10;
pub const cr4_fsgsbase: u64 = 1 << 16;
pub const cr4_osxsave: u64 = 1 << 18;
pub const cr4_smep: u64 = 1 << 20;
pub const cr4_smap: u64 = 1 << 21;

pub fn jump_to_kernel(
    entry_point: u64,
    stack_top: u64,
    boot_params: u64,
    pml4_address: u64,
) noreturn {
    disable_interrupts();

    write_cr3(pml4_address);

    asm volatile (
        \\mov %[stack], %%rsp
        \\mov %[params], %%rdi
        \\xor %%rbp, %%rbp
        \\jmp *%[entry]
        :
        : [stack] "r" (stack_top),
          [params] "r" (boot_params),
          [entry] "r" (entry_point),
        : .{ .memory = true });

    unreachable;
}
