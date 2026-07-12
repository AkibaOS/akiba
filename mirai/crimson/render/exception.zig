//! Render Exception Info

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const classify = @import("../classify/classify.zig");
const messages = @import("../strings/strings.zig").messages;

const Exception = types.Exception;
const PageFaultError = classify.PageFaultError;

pub fn render(exception: *const Exception) void {
    serial.printf(messages.EXCEPTION_LINE, .{
        exception.exception_type.name(),
        classify.get_vector_name(exception.vector),
    });

    serial.printf(messages.VECTOR, .{exception.vector});
    serial.printf(messages.CODE, .{exception.code});
    serial.printf(messages.SUBCODE, .{exception.subcode});

    if (exception.address != 0) {
        serial.printf(messages.FAULT_ADDRESS, .{exception.address});
    }

    if (exception.vector == 14) {
        render_page_fault_details(exception.code);
    }

    serial.printf(messages.LOCATION, .{
        if (exception.context.is_kernel_mode()) messages.LOCATION_KERNEL else messages.LOCATION_USER,
    });

    if (exception.kata_id != 0) {
        serial.printf(messages.KATA_THREAD, .{ exception.kata_id, exception.thread_id });
    }

    serial.printf("\n", .{});
}

fn render_page_fault_details(error_code: u64) void {
    const pf_error = PageFaultError.from_error_code(error_code);

    serial.printf(messages.ACCESS, .{pf_error.description()});

    if (pf_error.user) {
        serial.printf(messages.MODE_USER, .{});
    } else {
        serial.printf(messages.MODE_KERNEL, .{});
    }
}

pub fn render_faulting_instruction(rip: u64) void {
    serial.printf(messages.FAULTING_INSTRUCTION_HEADER, .{});
    serial.printf(messages.ADDRESS, .{rip});

    const code_ptr: [*]const u8 = @ptrFromInt(rip);
    serial.printf(messages.BYTES_LABEL, .{});
    for (0..8) |i| {
        serial.printf("%x ", .{code_ptr[i]});
    }
    serial.printf("\n\n", .{});
}
