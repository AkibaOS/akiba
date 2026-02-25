//! Segment Register Operations

pub fn reload_code_segment(code_selector: u16) void {
    asm volatile (
        \\push %[code_sel]
        \\lea 1f(%%rip), %%rax
        \\push %%rax
        \\lretq
        \\1:
        :
        : [code_sel] "r" (@as(u64, code_selector)),
        : .{ .rax = true, .memory = true }
    );
}

pub fn reload_data_segments(data_selector: u16) void {
    asm volatile (
        \\mov %[data_sel], %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%ax, %%ss
        :
        : [data_sel] "r" (data_selector),
        : .{ .rax = true, .memory = true }
    );
}

pub fn load_tss(tss_selector: u16) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (tss_selector),
    );
}

pub fn get_cs() u16 {
    var cs: u16 = undefined;
    asm volatile ("mov %%cs, %[cs]"
        : [cs] "=r" (cs),
    );
    return cs;
}

pub fn get_ds() u16 {
    var ds: u16 = undefined;
    asm volatile ("mov %%ds, %[ds]"
        : [ds] "=r" (ds),
    );
    return ds;
}

pub fn get_ss() u16 {
    var ss: u16 = undefined;
    asm volatile ("mov %%ss, %[ss]"
        : [ss] "=r" (ss),
    );
    return ss;
}

pub fn get_es() u16 {
    var es: u16 = undefined;
    asm volatile ("mov %%es, %[es]"
        : [es] "=r" (es),
    );
    return es;
}

pub fn get_fs() u16 {
    var fs: u16 = undefined;
    asm volatile ("mov %%fs, %[fs]"
        : [fs] "=r" (fs),
    );
    return fs;
}

pub fn get_gs() u16 {
    var gs: u16 = undefined;
    asm volatile ("mov %%gs, %[gs]"
        : [gs] "=r" (gs),
    );
    return gs;
}
