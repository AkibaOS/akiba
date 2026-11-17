//! Actual Persona Page Permission Faults

const std = @import("std");

const common = @import("common");
const drive = @import("tests").guest.support.drive;
const inputs = @import("tests").constants.access;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.access;
const locations = @import("tests").constants.guest;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const Kata = kata.types.kata.Kata;

extern var __kernel_text_start: u8;

pub fn run() !void {
    try writing();
    try executing();
    try supervisor();
}

fn prepare() !*Kata {
    const owner = try kata.create.create();
    errdefer support.dispose(owner.ID) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(owner, locations.CODE_ADDRESS);
    try user.memory.allocate.allocate(owner, locations.STACK_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.DATA_ADDRESS);
    try user.memory.load.load(owner, inputs.DATA_ADDRESS, &inputs.RETURN);
    try user.memory.finalize.finalize(owner, locations.STACK_ADDRESS, .ReadWrite);
    return owner;
}

fn writing() !void {
    const owner = try prepare();
    const identifier = owner.ID;
    defer support.dispose(identifier) catch |failure| verify.failure(failure);
    var bytes = inputs.WRITE;
    std.mem.writeInt(u64, bytes[inputs.ADDRESS_OFFSET..][0..inputs.OPERAND_BYTES], inputs.DATA_ADDRESS, .little);
    try user.memory.finalize.finalize(owner, inputs.DATA_ADDRESS, .ReadOnly);
    try runFault(owner, &bytes, inputs.DATA_ADDRESS, inputs.WRITE_ERROR, locations.CODE_ADDRESS + inputs.INSTRUCTION_OFFSET, labels.WRITE);
}

fn executing() !void {
    const owner = try prepare();
    const identifier = owner.ID;
    defer support.dispose(identifier) catch |failure| verify.failure(failure);
    var bytes = inputs.EXECUTE;
    std.mem.writeInt(u64, bytes[inputs.ADDRESS_OFFSET..][0..inputs.OPERAND_BYTES], inputs.DATA_ADDRESS, .little);
    try user.memory.finalize.finalize(owner, inputs.DATA_ADDRESS, .ReadWrite);
    try runFault(owner, &bytes, inputs.DATA_ADDRESS, inputs.EXECUTE_ERROR, inputs.DATA_ADDRESS, labels.EXECUTE);
}

fn supervisor() !void {
    const owner = try prepare();
    const identifier = owner.ID;
    defer support.dispose(identifier) catch |failure| verify.failure(failure);
    const address = @intFromPtr(&__kernel_text_start);
    var bytes = inputs.READ;
    std.mem.writeInt(u64, bytes[inputs.ADDRESS_OFFSET..][0..inputs.OPERAND_BYTES], address, .little);
    try user.memory.finalize.finalize(owner, inputs.DATA_ADDRESS, .ReadWrite);
    try runFault(owner, &bytes, address, inputs.SUPERVISOR_ERROR, locations.CODE_ADDRESS + inputs.INSTRUCTION_OFFSET, labels.SUPERVISOR);
}

fn runFault(owner: *Kata, bytes: []const u8, address: u64, code: u64, instruction: u64, comptime name: []const u8) !void {
    const identifier = owner.ID;
    try user.memory.load.load(owner, locations.CODE_ADDRESS, bytes);
    try user.memory.finalize.finalize(owner, locations.CODE_ADDRESS, .ReadExecute);
    const target = try thread.user.create(owner, locations.CODE_ADDRESS, locations.STACK_ADDRESS, common.constants.memory.sizes.PAGE_SIZE, 0);
    try sensei.control.start(target);
    drive.run();
    const outcome = try kata.completion.lifetime.collect(identifier);
    verify.require(outcome == .Faulted and outcome.Faulted.Vector == inputs.PAGE_FAULT_VECTOR and
        outcome.Faulted.Code == code and outcome.Faulted.Address == address and outcome.Faulted.Instruction == instruction and
        kata.state.findByID(identifier) == null and kata.completion.storage.ownerOf(identifier) == null, name);
}
