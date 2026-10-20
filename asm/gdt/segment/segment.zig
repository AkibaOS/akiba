//! Segment Register Operations

const strings = @import("asm").gdt.strings.segment;

pub fn readCodeSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_CODE_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDataSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_DATA_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn readStackSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_STACK_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn readExtraSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_EXTRA_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn readFsSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_FS_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn readGsSegment() u16 {
    var value: u16 = undefined;
    asm volatile (strings.READ_GS_SEGMENT
        : [value] "=r" (value),
    );
    return value;
}

pub fn reloadCodeSegment(code_selector: u16) void {
    asm volatile (strings.RELOAD_CODE_SEGMENT
        :
        : [selector] "r" (@as(u64, code_selector)),
        : .{ .rax = true, .memory = true });
}

pub fn reloadDataSegments(data_selector: u16) void {
    asm volatile (strings.RELOAD_DATA_SEGMENTS
        :
        : [selector] "r" (data_selector),
        : .{ .rax = true, .memory = true });
}

pub fn loadTaskStateSegment(selector: u16) void {
    asm volatile (strings.LOAD_TASK_STATE_SEGMENT
        :
        : [selector] "r" (selector),
    );
}
