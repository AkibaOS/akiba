//! Render Exception Info

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const classify = @import("../classify/classify.zig");
const messages = @import("strings/strings.zig").messages;

const Exception = types.Exception;
const PageFaultError = classify.PageFaultError;

pub fn render(exception: *const Exception) void {
    serial.printf(messages.exception_line, .{
        exception.exception_type.name(),
        classify.get_vector_name(exception.vector),
    });

    serial.printf(messages.vector, .{exception.vector});
    serial.printf(messages.code, .{exception.code});
    serial.printf(messages.subcode, .{exception.subcode});

    if (exception.address != 0) {
        serial.printf(messages.fault_address, .{exception.address});
    }

    if (exception.vector == 14) {
        render_page_fault_details(exception.code);
    }

    serial.printf(messages.location, .{
        if (exception.context.is_kernel_mode()) messages.location_kernel else messages.location_user,
    });

    if (exception.kata_id != 0) {
        serial.printf(messages.kata_thread, .{ exception.kata_id, exception.thread_id });
    }

    serial.printf("\n", .{});
}

fn render_page_fault_details(error_code: u64) void {
    const pf_error = PageFaultError.from_error_code(error_code);

    serial.printf(messages.access, .{pf_error.description()});

    if (pf_error.user) {
        serial.printf(messages.mode_user, .{});
    } else {
        serial.printf(messages.mode_kernel, .{});
    }
}

pub fn render_faulting_instruction(rip: u64) void {
    serial.printf(messages.faulting_instruction_header, .{});
    serial.printf(messages.address, .{rip});

    const code_ptr: [*]const u8 = @ptrFromInt(rip);
    serial.printf(messages.bytes_label, .{});
    for (0..8) |i| {
        serial.printf("%x ", .{code_ptr[i]});
    }
    serial.printf("\n\n", .{});
}
