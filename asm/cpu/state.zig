//! CPU State Operations

pub fn read_rsp() u64 {
    var rsp: u64 = undefined;
    asm volatile ("mov %%rsp, %[rsp]"
        : [rsp] "=r" (rsp),
    );
    return rsp;
}

pub fn read_rbp() u64 {
    var rbp: u64 = undefined;
    asm volatile ("mov %%rbp, %[rbp]"
        : [rbp] "=r" (rbp),
    );
    return rbp;
}

pub fn rdtsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | low;
}

pub fn read_ds() u16 {
    var ds: u16 = undefined;
    asm volatile ("mov %%ds, %[ds]"
        : [ds] "=r" (ds),
    );
    return ds;
}

pub fn read_es() u16 {
    var es: u16 = undefined;
    asm volatile ("mov %%es, %[es]"
        : [es] "=r" (es),
    );
    return es;
}

pub fn read_fs() u16 {
    var fs: u16 = undefined;
    asm volatile ("mov %%fs, %[fs]"
        : [fs] "=r" (fs),
    );
    return fs;
}

pub fn read_gs() u16 {
    var gs: u16 = undefined;
    asm volatile ("mov %%gs, %[gs]"
        : [gs] "=r" (gs),
    );
    return gs;
}

pub fn clear_task_switched() void {
    asm volatile (
        \\mov %%cr0, %%rax
        \\and $~8, %%rax
        \\mov %%rax, %%cr0
        ::: .{ .rax = true });
}
