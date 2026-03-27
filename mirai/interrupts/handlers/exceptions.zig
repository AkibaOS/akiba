//! Exception Handler Stubs (Vectors 0-31)

const common = @import("common.zig");
const InterruptFrame = common.InterruptFrame;
const asm_stubs = @import("../../asm/interrupts/stubs.zig");

const crimson = @import("../../crimson/crimson.zig");

export fn exception_dispatch(frame: *InterruptFrame) void {
    const vector: u8 = @truncate(frame.vector);

    var exception = crimson.handlers.create_exception(
        vector,
        frame.error_code,
        frame.rip,
        frame.rsp,
    );

    const action = crimson.handlers.dispatch(&exception);

    switch (action) {
        .resume_execution => {},
        .terminate => crimson.collapse(&exception),
        .collapse => crimson.collapse(&exception),
        else => crimson.collapse(&exception),
    }
}

pub const exception_0 = asm_stubs.make_exception_handler(0, false);
pub const exception_1 = asm_stubs.make_exception_handler(1, false);
pub const exception_2 = asm_stubs.make_exception_handler(2, false);
pub const exception_3 = asm_stubs.make_exception_handler(3, false);
pub const exception_4 = asm_stubs.make_exception_handler(4, false);
pub const exception_5 = asm_stubs.make_exception_handler(5, false);
pub const exception_6 = asm_stubs.make_exception_handler(6, false);
pub const exception_7 = asm_stubs.make_exception_handler(7, false);
pub const exception_8 = asm_stubs.make_exception_handler(8, true);
pub const exception_9 = asm_stubs.make_exception_handler(9, false);
pub const exception_10 = asm_stubs.make_exception_handler(10, true);
pub const exception_11 = asm_stubs.make_exception_handler(11, true);
pub const exception_12 = asm_stubs.make_exception_handler(12, true);
pub const exception_13 = asm_stubs.make_exception_handler(13, true);
pub const exception_14 = asm_stubs.make_exception_handler(14, true);
pub const exception_15 = asm_stubs.make_exception_handler(15, false);
pub const exception_16 = asm_stubs.make_exception_handler(16, false);
pub const exception_17 = asm_stubs.make_exception_handler(17, true);
pub const exception_18 = asm_stubs.make_exception_handler(18, false);
pub const exception_19 = asm_stubs.make_exception_handler(19, false);
pub const exception_20 = asm_stubs.make_exception_handler(20, false);
pub const exception_21 = asm_stubs.make_exception_handler(21, true);
pub const exception_22 = asm_stubs.make_exception_handler(22, false);
pub const exception_23 = asm_stubs.make_exception_handler(23, false);
pub const exception_24 = asm_stubs.make_exception_handler(24, false);
pub const exception_25 = asm_stubs.make_exception_handler(25, false);
pub const exception_26 = asm_stubs.make_exception_handler(26, false);
pub const exception_27 = asm_stubs.make_exception_handler(27, false);
pub const exception_28 = asm_stubs.make_exception_handler(28, false);
pub const exception_29 = asm_stubs.make_exception_handler(29, true);
pub const exception_30 = asm_stubs.make_exception_handler(30, true);
pub const exception_31 = asm_stubs.make_exception_handler(31, false);

pub const stubs = [32]*const fn () callconv(.Naked) void{
    &exception_0,  &exception_1,  &exception_2,  &exception_3,
    &exception_4,  &exception_5,  &exception_6,  &exception_7,
    &exception_8,  &exception_9,  &exception_10, &exception_11,
    &exception_12, &exception_13, &exception_14, &exception_15,
    &exception_16, &exception_17, &exception_18, &exception_19,
    &exception_20, &exception_21, &exception_22, &exception_23,
    &exception_24, &exception_25, &exception_26, &exception_27,
    &exception_28, &exception_29, &exception_30, &exception_31,
};
