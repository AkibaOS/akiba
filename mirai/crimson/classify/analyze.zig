//! Analyze Error Codes

pub const PageFaultError = struct {
    present: bool,
    write: bool,
    user: bool,
    reserved_write: bool,
    instruction_fetch: bool,
    pub fn from_error_code(code: u64) PageFaultError {
        return PageFaultError{
            .present = (code & 1) != 0,
            .write = (code & 2) != 0,
            .user = (code & 4) != 0,
            .reserved_write = (code & 8) != 0,
            .instruction_fetch = (code & 16) != 0,
        };
    }
    pub fn is_not_present(self: PageFaultError) bool {
        return !self.present;
    }
    pub fn is_write_access(self: PageFaultError) bool {
        return self.write;
    }
    pub fn is_execute_access(self: PageFaultError) bool {
        return self.instruction_fetch;
    }
    pub fn description(self: PageFaultError) []const u8 {
        if (self.instruction_fetch) return if (self.present) "Execute on non-executable page" else "Execute on non-present page";
        if (self.write) return if (self.present) "Write to read-only page" else "Write to non-present page";
        return if (self.present) "Read from protected page" else "Read from non-present page";
    }
};

pub const SelectorError = struct {
    external: bool,
    table: u2,
    index: u13,
    pub fn from_error_code(code: u64) SelectorError {
        return SelectorError{ .external = (code & 1) != 0, .table = @truncate((code >> 1) & 0x3), .index = @truncate((code >> 3) & 0x1FFF) };
    }
};
