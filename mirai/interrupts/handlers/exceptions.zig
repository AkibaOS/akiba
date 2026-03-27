//! Exception Handler Stubs (Vectors 0-31)

const common = @import("common.zig");
const InterruptFrame = common.InterruptFrame;
const asm_stubs = @import("../../asm/interrupts/stubs.zig");

const crimson = @import("../../crimson/crimson.zig");

fn make_handler(comptime vector: u8, comptime has_error_code: bool) fn () callconv(.Naked) void {
    return struct {
        fn handler() callconv(.Naked) void {
            if (!has_error_code) {
                asm volatile ("push $0");
            }
            asm volatile ("push %[v]"
                :
                : [v] "i" (vector),
            );
            asm volatile (asm_stubs.push_all ++
                    \\mov %%rsp, %%rdi
                    \\call exception_dispatch
                ++ asm_stubs.pop_all ++ asm_stubs.iret_cleanup);
        }
    }.handler;
}

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

pub const exception_0 = make_handler(0, false);
pub const exception_1 = make_handler(1, false);
pub const exception_2 = make_handler(2, false);
pub const exception_3 = make_handler(3, false);
pub const exception_4 = make_handler(4, false);
pub const exception_5 = make_handler(5, false);
pub const exception_6 = make_handler(6, false);
pub const exception_7 = make_handler(7, false);
pub const exception_8 = make_handler(8, true);
pub const exception_9 = make_handler(9, false);
pub const exception_10 = make_handler(10, true);
pub const exception_11 = make_handler(11, true);
pub const exception_12 = make_handler(12, true);
pub const exception_13 = make_handler(13, true);
pub const exception_14 = make_handler(14, true);
pub const exception_15 = make_handler(15, false);
pub const exception_16 = make_handler(16, false);
pub const exception_17 = make_handler(17, true);
pub const exception_18 = make_handler(18, false);
pub const exception_19 = make_handler(19, false);
pub const exception_20 = make_handler(20, false);
pub const exception_21 = make_handler(21, true);
pub const exception_22 = make_handler(22, false);
pub const exception_23 = make_handler(23, false);
pub const exception_24 = make_handler(24, false);
pub const exception_25 = make_handler(25, false);
pub const exception_26 = make_handler(26, false);
pub const exception_27 = make_handler(27, false);
pub const exception_28 = make_handler(28, false);
pub const exception_29 = make_handler(29, true);
pub const exception_30 = make_handler(30, true);
pub const exception_31 = make_handler(31, false);

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
