//! GDT Load Instructions

pub const Gdtr = packed struct {
    limit: u16,
    base: u64,
};

pub fn lgdt(gdtr: *const Gdtr) void {
    asm volatile ("lgdt (%[gdtr])"
        :
        : [gdtr] "r" (gdtr),
        : .{ .memory = true }
    );
}

pub fn sgdt() Gdtr {
    var gdtr: Gdtr = undefined;
    asm volatile ("sgdt (%[gdtr])"
        :
        : [gdtr] "r" (&gdtr),
        : .{ .memory = true }
    );
    return gdtr;
}
