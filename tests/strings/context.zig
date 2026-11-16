//! Native Thread Context Check Strings

pub const GROUP = "CHECK GROUP Native Thread context\n";
pub const CONSTRUCTION_VALID = "Persona construction creates one unpublished Thread with validated entry stack and argument";
pub const CONSTRUCTION_ENTRY = "Persona invalid missing and non-executable entries reject after temporary Thread construction";
pub const CONSTRUCTION_STACK = "Persona malformed stack geometry rejects before publication";
pub const CONSTRUCTION_ROLLBACK = "failed Persona construction restores descriptor owner pin cache and warmed PMM ownership";
pub const DESTRUCTION_IN_USE = "managed Thread destruction returns InUse without withdrawing live resources";
pub const INVALID_STATE = "Invalid native Thread context check state";
pub const ARGUMENT_TRANSFER = "fresh Thread receives its exact argument once";
pub const CALLEE_REGISTERS = "callee GPR patterns survive real yields and timer preemption";
pub const STACK_RESUME = "Thread stack pointers alignment and canaries survive yields";
pub const INTERRUPT_FLAGS = "interrupt guards and resumed IF preserve their contracts";
pub const KAGAMI_CR3 = "distinct Kata Kagami roots match hardware CR3 after switches";
pub const TSS_STACK = "TSS RSP0 follows each running Thread stack";
pub const TIMER_PREEMPTION = "bounded call-free peers make progress through timer preemption";
pub const X87_STATE = "timer preemption preserves distinct x87 stacks and control words";
pub const SSE_STATE = "timer preemption preserves both halves of XMM0 and XMM15";
pub const MXCSR_STATE = "timer preemption preserves distinct valid MXCSR controls";
pub const LAUNCHER_RESTORE = "launcher Thread Kagami TSS stack and IF resume intact";
pub const DISPOSABLE_CLEANUP = "disposable Threads Katas and completion records are reclaimed";

pub const EMPTY = "";
pub const COOPERATIVE_SYMBOL = "akiba_test_context_cooperative";
pub const PREEMPTIVE_SYMBOL = "akiba_test_context_preemptive";
pub const COOPERATIVE_PREFIX = "CONTEXT_COOPERATIVE";
pub const PREEMPTIVE_PREFIX = "CONTEXT_PREEMPTIVE";
pub const REGISTERS_PREFIX = "CONTEXT_REGISTERS";
pub const FLOATING_PREFIX = "CONTEXT_FLOATING";
pub const OFFSET_FORMAT = ".set {s}_{s}, {d}\n";
pub const FRAME_FORMAT = ".set CONTEXT_COOPERATIVE_FRAME, {d}\n.set CONTEXT_FPU_FRAME, {d}\n.set CONTEXT_ARMED, {d}\n.set CONTEXT_PROGRESSED, {d}\n";

pub const COOPERATIVE =
    \\pushq %%rbx
    \\pushq %%rbp
    \\pushq %%r12
    \\pushq %%r13
    \\pushq %%r14
    \\pushq %%r15
    \\subq $CONTEXT_COOPERATIVE_FRAME, %%rsp
    \\movq %%rdi, 0(%%rsp)
    \\movq %%rsi, 8(%%rsp)
    \\movq %%rdx, 16(%%rsp)
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_RBX(%%rdi), %%rbx
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_RBP(%%rdi), %%rbp
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_R12(%%rdi), %%r12
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_R13(%%rdi), %%r13
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_R14(%%rdi), %%r14
    \\movq CONTEXT_COOPERATIVE_Seed+CONTEXT_REGISTERS_R15(%%rdi), %%r15
    \\movq %%rsp, CONTEXT_COOPERATIVE_BeforeRSP(%%rdi)
    \\pushfq
    \\popq %%rax
    \\movq %%rax, CONTEXT_COOPERATIVE_BeforeFlags(%%rdi)
    \\movq 16(%%rsp), %%rdi
    \\callq *8(%%rsp)
    \\movq 0(%%rsp), %%rdi
    \\movq %%rsp, CONTEXT_COOPERATIVE_AfterRSP(%%rdi)
    \\pushfq
    \\popq %%rax
    \\movq %%rax, CONTEXT_COOPERATIVE_AfterFlags(%%rdi)
    \\movq %%rbx, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_RBX(%%rdi)
    \\movq %%rbp, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_RBP(%%rdi)
    \\movq %%r12, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_R12(%%rdi)
    \\movq %%r13, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_R13(%%rdi)
    \\movq %%r14, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_R14(%%rdi)
    \\movq %%r15, CONTEXT_COOPERATIVE_Actual+CONTEXT_REGISTERS_R15(%%rdi)
    \\addq $CONTEXT_COOPERATIVE_FRAME, %%rsp
    \\popq %%r15
    \\popq %%r14
    \\popq %%r13
    \\popq %%r12
    \\popq %%rbp
    \\popq %%rbx
    \\retq
;

pub const PREEMPTIVE =
    \\pushq %%rbx
    \\pushq %%rbp
    \\pushq %%r12
    \\pushq %%r13
    \\pushq %%r14
    \\pushq %%r15
    \\subq $CONTEXT_FPU_FRAME, %%rsp
    \\fxsave64 (%%rsp)
    \\fninit
    \\fldcw CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_Control(%%rdi)
    \\fldl CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_X87+8(%%rdi)
    \\fldl CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_X87(%%rdi)
    \\movdqu CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_XMM0(%%rdi), %%xmm0
    \\movdqu CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_XMM15(%%rdi), %%xmm15
    \\ldmxcsr CONTEXT_PREEMPTIVE_Seed+CONTEXT_FLOATING_MXCSR(%%rdi)
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_RBX(%%rdi), %%rbx
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_RBP(%%rdi), %%rbp
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_R12(%%rdi), %%r12
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_R13(%%rdi), %%r13
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_R14(%%rdi), %%r14
    \\movq CONTEXT_PREEMPTIVE_SeedRegisters+CONTEXT_REGISTERS_R15(%%rdi), %%r15
    \\pushfq
    \\popq %%rax
    \\movq %%rax, CONTEXT_PREEMPTIVE_BeforeFlags(%%rdi)
    \\movq CONTEXT_PREEMPTIVE_Budget(%%rdi), %%rcx
    \\movl $CONTEXT_ARMED, CONTEXT_PREEMPTIVE_Stage(%%rdi)
    \\1:
    \\cmpl $CONTEXT_ARMED, CONTEXT_PREEMPTIVE_Stage(%%rsi)
    \\jae 2f
    \\testq %%rcx, %%rcx
    \\jz 9f
    \\decq %%rcx
    \\pause
    \\jmp 1b
    \\2:
    \\movl $CONTEXT_PROGRESSED, CONTEXT_PREEMPTIVE_Stage(%%rdi)
    \\3:
    \\cmpl $CONTEXT_PROGRESSED, CONTEXT_PREEMPTIVE_Stage(%%rsi)
    \\jae 4f
    \\testq %%rcx, %%rcx
    \\jz 9f
    \\decq %%rcx
    \\pause
    \\jmp 3b
    \\9:
    \\movl $1, CONTEXT_PREEMPTIVE_TimedOut(%%rdi)
    \\movl $CONTEXT_PROGRESSED, CONTEXT_PREEMPTIVE_Stage(%%rdi)
    \\4:
    \\pushfq
    \\popq %%rax
    \\movq %%rax, CONTEXT_PREEMPTIVE_AfterFlags(%%rdi)
    \\movq %%rbx, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_RBX(%%rdi)
    \\movq %%rbp, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_RBP(%%rdi)
    \\movq %%r12, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_R12(%%rdi)
    \\movq %%r13, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_R13(%%rdi)
    \\movq %%r14, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_R14(%%rdi)
    \\movq %%r15, CONTEXT_PREEMPTIVE_ActualRegisters+CONTEXT_REGISTERS_R15(%%rdi)
    \\fnstcw CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_Control(%%rdi)
    \\fstpl CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_X87(%%rdi)
    \\fstpl CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_X87+8(%%rdi)
    \\movdqu %%xmm0, CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_XMM0(%%rdi)
    \\movdqu %%xmm15, CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_XMM15(%%rdi)
    \\stmxcsr CONTEXT_PREEMPTIVE_Actual+CONTEXT_FLOATING_MXCSR(%%rdi)
    \\fxrstor64 (%%rsp)
    \\addq $CONTEXT_FPU_FRAME, %%rsp
    \\popq %%r15
    \\popq %%r14
    \\popq %%r13
    \\popq %%r12
    \\popq %%rbp
    \\popq %%rbx
    \\retq
;
