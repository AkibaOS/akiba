//! Analyze Error Codes

const constants = @import("mirai").crimson.constants;
const strings = @import("mirai").crimson.strings;

const faults = constants.faults;
const names = strings.names;

pub const PageFaultError = struct {
    Present: bool,
    Write: bool,
    User: bool,
    ReservedWrite: bool,
    InstructionFetch: bool,

    pub fn fromErrorCode(code: u64) PageFaultError {
        return PageFaultError{
            .Present = (code & faults.PAGE_FAULT_PRESENT) != 0,
            .Write = (code & faults.PAGE_FAULT_WRITE) != 0,
            .User = (code & faults.PAGE_FAULT_USER) != 0,
            .ReservedWrite = (code & faults.PAGE_FAULT_RESERVED_WRITE) != 0,
            .InstructionFetch = (code & faults.PAGE_FAULT_INSTRUCTION_FETCH) != 0,
        };
    }

    pub fn isNotPresent(self: PageFaultError) bool {
        return !self.Present;
    }

    pub fn isWriteAccess(self: PageFaultError) bool {
        return self.Write;
    }

    pub fn isExecuteAccess(self: PageFaultError) bool {
        return self.InstructionFetch;
    }

    pub fn description(self: PageFaultError) []const u8 {
        if (self.InstructionFetch) return if (self.Present) names.ACCESS_EXECUTE_NON_EXECUTABLE else names.ACCESS_EXECUTE_NON_PRESENT;
        if (self.Write) return if (self.Present) names.ACCESS_WRITE_READ_ONLY else names.ACCESS_WRITE_NON_PRESENT;
        return if (self.Present) names.ACCESS_READ_PROTECTED else names.ACCESS_READ_NON_PRESENT;
    }
};

pub const SelectorError = struct {
    External: bool,
    Table: u2,
    Index: u13,

    pub fn fromErrorCode(code: u64) SelectorError {
        return SelectorError{
            .External = (code & faults.SELECTOR_EXTERNAL) != 0,
            .Table = @truncate((code >> faults.SELECTOR_TABLE_SHIFT) & faults.SELECTOR_TABLE_MASK),
            .Index = @truncate((code >> faults.SELECTOR_INDEX_SHIFT) & faults.SELECTOR_INDEX_MASK),
        };
    }
};
