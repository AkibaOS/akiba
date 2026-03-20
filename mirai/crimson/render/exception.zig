//! Render Exception Info

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const classify = @import("../classify/classify.zig");

const Exception = types.Exception;
const PageFaultError = classify.PageFaultError;

pub fn render(exception: *const Exception) void {
    serial.printf("Exception: %s (%s)\n", .{
        exception.exception_type.name(),
        classify.get_vector_name(exception.vector),
    });

    serial.printf("  Vector: %d\n", .{exception.vector});
    serial.printf("  Code: %x\n", .{exception.code});
    serial.printf("  Subcode: %x\n", .{exception.subcode});

    if (exception.address != 0) {
        serial.printf("  Fault Address: %x\n", .{exception.address});
    }

    if (exception.vector == 14) {
        render_page_fault_details(exception.code);
    }

    serial.printf("  Location: %s mode\n", .{
        if (exception.context.is_kernel_mode()) "kernel" else "user",
    });

    if (exception.kata_id != 0) {
        serial.printf("  Kata: %d, Thread: %d\n", .{ exception.kata_id, exception.thread_id });
    }

    serial.printf("\n", .{});
}

fn render_page_fault_details(error_code: u64) void {
    const pf_error = PageFaultError.from_error_code(error_code);

    serial.printf("  Access: %s\n", .{pf_error.description()});

    if (pf_error.user) {
        serial.printf("  Mode: User\n", .{});
    } else {
        serial.printf("  Mode: Kernel\n", .{});
    }
}

pub fn render_faulting_instruction(rip: u64) void {
    serial.printf("Faulting Instruction:\n", .{});
    serial.printf("  Address: %x\n", .{rip});

    const code_ptr: [*]const u8 = @ptrFromInt(rip);
    serial.printf("  Bytes: ", .{});
    for (0..8) |i| {
        serial.printf("%x ", .{code_ptr[i]});
    }
    serial.printf("\n\n", .{});
}
