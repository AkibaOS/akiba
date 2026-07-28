//! Vector Classification

const common = @import("common");

const constants = @import("mirai").crimson.constants;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const interrupts = common.constants.interrupts;

const ExceptionType = types.kind.ExceptionType;

pub fn classifyVector(vector_number: u8) ExceptionType {
    for (constants.vectors.VECTORS) |vector| {
        if (vector.Number == vector_number) return vector.ExceptionType;
    }
    return .Forbidden;
}

pub fn getVectorName(vector_number: u8) []const u8 {
    for (constants.vectors.VECTORS) |vector| {
        if (vector.Number == vector_number) return vector.Name;
    }
    return strings.names.VECTOR_UNKNOWN;
}

pub fn vectorHasErrorCode(vector_number: u8) bool {
    for (constants.vectors.VECTORS) |vector| {
        if (vector.Number == vector_number) return vector.HasErrorCode;
    }
    return false;
}

pub fn isExceptionVector(vector_number: u8) bool {
    return vector_number < interrupts.vectors.EXCEPTION_COUNT;
}
