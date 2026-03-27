//! IDT Assembly Operations

pub fn lidt(desc: *const anyopaque) void {
    asm volatile ("lidt (%[desc])"
        :
        : [desc] "r" (desc),
        : .{ .memory = true }
    );
}

pub fn sidt(desc: *anyopaque) void {
    asm volatile ("sidt (%[desc])"
        :
        : [desc] "r" (desc),
        : .{ .memory = true }
    );
}
