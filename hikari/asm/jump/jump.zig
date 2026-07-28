//! Hikari Kernel Jump

pub fn jumpToKernel(
    entry_point: u64,
    stack_top: u64,
    boot_params: u64,
    pml4_address: u64,
) noreturn {
    asm volatile (
        \\cli
        \\mov %[pml4], %%cr3
        \\mov %[stack], %%rsp
        \\mov %[params], %%rdi
        \\xor %%rbp, %%rbp
        \\push $0
        \\jmp *%[entry]
        :
        : [pml4] "r" (pml4_address),
          [stack] "r" (stack_top),
          [params] "r" (boot_params),
          [entry] "r" (entry_point),
        : .{ .memory = true });

    unreachable;
}
