//! Bounded Persona Invocation Program Encoding

const std = @import("std");

const abi = @import("mirai").invocations.types.abi;
const constants = @import("tests").constants.postman;
const types = @import("tests").types.postman;

const Actor = types.Actor;
const FixtureError = types.FixtureError;
const InvocationResult = types.InvocationResult;
const Operation = types.Operation;
const Program = types.Program;

pub fn encode(actor: *const Actor, operations: []const Operation) FixtureError!Program {
    if (operations.len == 0 or operations.len > constants.MAX_STEPS) return FixtureError.InvalidFixture;
    var program: Program = .{ .Bytes = @splat(0), .Length = 0 };
    for (operations, 0..) |operation, index| {
        try immediate(&program, &constants.MOV_RAX, operation.ServiceValue orelse @intFromEnum(operation.Service));
        switch (operation.First) {
            .Immediate => |value| try immediate(&program, &constants.MOV_RDI, value),
            .Indirect => |address| {
                try immediate(&program, &constants.MOV_RDI, address);
                try emit(&program, &constants.LOAD_RDI);
            },
        }
        try immediate(&program, &constants.MOV_RSI, operation.Second);
        try immediate(&program, &constants.MOV_RDX, operation.Third);
        try immediate(&program, &constants.MOV_R10, operation.LetterType);
        try emit(&program, &constants.INVOKE);
        try immediate(&program, &constants.MOV_R11, actor.Data + constants.RESULT_OFFSET + index * @sizeOf(InvocationResult));
        try emit(&program, &constants.STORE_RESULT);
        try immediate(&program, &constants.MOV_R11, actor.Data + @sizeOf(u64));
        try immediate(&program, &constants.MOV_RAX, index + 1);
        try emit(&program, &constants.STORE_RAX);
        const loop = program.Length;
        try immediate(&program, &constants.MOV_RAX, @intFromEnum(abi.Service.Yield));
        try emit(&program, &constants.INVOKE);
        try immediate(&program, &constants.MOV_R11, actor.Data);
        try emit(&program, &constants.COMPARE_GATE);
        try emit(&program, &.{@intCast(index + 1)});
        const displacement: i16 = @as(i16, @intCast(loop)) - @as(i16, @intCast(program.Length + 2));
        try emit(&program, &.{ constants.JUMP_BELOW, @bitCast(@as(i8, @intCast(displacement))) });
    }
    try immediate(&program, &constants.MOV_RAX, @intFromEnum(abi.Service.FinishThread));
    try emit(&program, &constants.INVOKE);
    try emit(&program, &constants.INVALID_OPCODE);
    return program;
}

fn immediate(program: *Program, opcode: []const u8, value: u64) FixtureError!void {
    try emit(program, opcode);
    var bytes: [@sizeOf(u64)]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try emit(program, &bytes);
}

fn emit(program: *Program, bytes: []const u8) FixtureError!void {
    if (bytes.len > program.Bytes.len - program.Length) return FixtureError.InvalidFixture;
    @memcpy(program.Bytes[program.Length..][0..bytes.len], bytes);
    program.Length += bytes.len;
}
