//! Segment Register Operations

pub fn readCodeSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%cs, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDataSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%ds, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readStackSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%ss, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readExtraSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%es, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readFsSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%fs, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readGsSegment() u16 {
    var value: u16 = undefined;
    asm volatile ("mov %%gs, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn reloadCodeSegment(code_selector: u16) void {
    asm volatile (
        \\push %[selector]
        \\lea 1f(%%rip), %%rax
        \\push %%rax
        \\lretq
        \\1:
        :
        : [selector] "r" (@as(u64, code_selector)),
        : .{ .rax = true, .memory = true });
}

pub fn reloadDataSegments(data_selector: u16) void {
    asm volatile (
        \\mov %[selector], %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%ax, %%ss
        :
        : [selector] "r" (data_selector),
        : .{ .rax = true, .memory = true });
}

pub fn loadTaskStateSegment(selector: u16) void {
    asm volatile ("ltr %[selector]"
        :
        : [selector] "r" (selector),
    );
}
