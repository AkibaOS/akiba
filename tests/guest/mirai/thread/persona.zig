//! Persona Mode Fault Regression

const common = @import("common");
const drive = @import("tests").guest.support.drive;
const inputs = @import("tests").constants.guest;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const owner = try kata.create.create();
    const id = owner.ID;
    try user.memory.allocate.allocate(owner, inputs.CODE_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.STACK_ADDRESS);
    try user.memory.load.load(owner, inputs.CODE_ADDRESS, &inputs.INVALID_OPCODE);
    try user.memory.finalize.finalize(owner, inputs.CODE_ADDRESS, .ReadExecute);
    try user.memory.finalize.finalize(owner, inputs.STACK_ADDRESS, .ReadWrite);
    const target = try thread.user.create(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS, common.constants.memory.sizes.PAGE_SIZE, inputs.ENTRY_ARGUMENT);
    verify.require(target.Mode == .Persona, labels.PERSONA_MODE);
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Faulted and result.Faulted.Vector == inputs.INVALID_OPCODE_VECTOR and
        result.Faulted.Instruction == inputs.CODE_ADDRESS and kata.state.findByID(id) == null, labels.PERSONA_FAULT);
}
