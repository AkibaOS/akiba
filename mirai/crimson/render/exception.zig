//! Render Exception Info

const classify = @import("mirai").crimson.classify;
const constants = @import("mirai").crimson.constants;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const limits = constants.limits;
const messages = strings.messages;

const Exception = types.exception.Exception;
const PageFaultError = classify.analyze.PageFaultError;

pub fn render(exception: *const Exception) void {
    serial.write.printf(messages.EXCEPTION_LINE, .{
        exception.ExceptionType.name(),
        classify.vector.getVectorName(exception.Vector),
    });

    serial.write.printf(messages.VECTOR, .{exception.Vector});
    serial.write.printf(messages.CODE, .{exception.Code});
    serial.write.printf(messages.SUBCODE, .{exception.Subcode});

    if (exception.Address != 0) {
        serial.write.printf(messages.FAULT_ADDRESS, .{exception.Address});
    }

    if (exception.Vector == constants.vectors.PAGE_FAULT_VECTOR) {
        renderPageFaultDetails(exception.Code);
    }

    serial.write.printf(messages.LOCATION, .{
        if (exception.Context.isKernelMode()) messages.LOCATION_KERNEL else messages.LOCATION_USER,
    });

    if (exception.KataId != 0) {
        serial.write.printf(messages.KATA_THREAD, .{ exception.KataId, exception.ThreadId });
    }

    serial.write.printf("\n", .{});
}

fn renderPageFaultDetails(error_code: u64) void {
    const fault = PageFaultError.fromErrorCode(error_code);

    serial.write.printf(messages.ACCESS, .{fault.description()});

    if (fault.User) {
        serial.write.printf(messages.MODE_USER, .{});
    } else {
        serial.write.printf(messages.MODE_KERNEL, .{});
    }
}

pub fn renderFaultingInstruction(rip: u64) void {
    serial.write.printf(messages.FAULTING_INSTRUCTION_HEADER, .{});
    serial.write.printf(messages.ADDRESS, .{rip});

    const code_pointer: [*]const u8 = @ptrFromInt(rip);
    serial.write.printf(messages.BYTES_LABEL, .{});
    for (0..limits.RENDER_INSTRUCTION_BYTES) |index| {
        serial.write.printf("%x ", .{code_pointer[index]});
    }
    serial.write.printf("\n\n", .{});
}
