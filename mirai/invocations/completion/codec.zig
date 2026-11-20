//! Deterministic Completion Record Encoding

const Outcome = @import("mirai").kata.types.outcome.Outcome;
const Record = @import("mirai").invocations.types.completion.record.Record;

pub fn encode(outcome: Outcome) Record {
    return switch (outcome) {
        .Completed => .{},
        .Exited => |result| .{ .Kind = .Exited, .Result = result },
        .Faulted => |fault| .{
            .Kind = .Faulted,
            .Vector = fault.Vector,
            .Code = fault.Code,
            .Address = fault.Address,
            .Instruction = fault.Instruction,
            .StackPointer = fault.StackPointer,
        },
    };
}
