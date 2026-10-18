//! Fixed Register Kernel Root Activation

const common = @import("common");
const constants = @import("asm").cpu.constants;
const halt = @import("asm").cpu.halt;
const strings = @import("asm").cpu.strings.transition;
const types = @import("asm").cpu.types.transition;

const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;

pub fn enterKernel(root: u64, stack: u64, continuation: types.Continuation, context: *const anyopaque) noreturn {
    if (root == 0 or (root & ~indices.ADDRESS_MASK) != 0 or
        stack < ~layout.USER_SPACE_END or (stack & (constants.transition.STACK_ALIGNMENT - 1)) != 0) halt.haltLoop();
    asm volatile (strings.ENTER_KERNEL
        :
        : [root] "{rdi}" (root),
          [stack] "{rsi}" (stack),
          [continuation] "{rdx}" (@intFromPtr(continuation)),
          [context] "{rcx}" (@intFromPtr(context)),
          [unsupported] "i" (constants.control.CR4_PCID_ENABLE | constants.control.CR4_LINEAR_ADDRESS_57_ENABLE),
          [global] "i" (constants.control.CR4_PAGE_GLOBAL_ENABLE),
          [nonglobal] "i" (@as(i32, @bitCast(~@as(u32, @intCast(constants.control.CR4_PAGE_GLOBAL_ENABLE))))),
        : .{ .rax = true, .r8 = true, .memory = true });
    unreachable;
}
