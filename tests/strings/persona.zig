//! Persona Invocation State Probe Assembly And Labels

pub const EMPTY = "";
pub const FINISHED_FIELD = "Finished";
pub const OFFSET = ".set {s}_{s}, {d}\n";
pub const VALUES = ".set PROBE_DATA, {d}\n.set PROBE_QUERY, {d}\n.set PROBE_YIELD, {d}\n";
pub const FRAME_PREFIX = "PROBE_FRAME";
pub const SNAPSHOT_PREFIX = "PROBE_SNAPSHOT";
pub const REGISTER_PREFIX = "PROBE_REG";
pub const FLOAT_PREFIX = "PROBE_FLOAT";
pub const SEED_BEGIN = ".macro PROBE_SEED where\n";
pub const SEED_REGISTER = "movq PROBE_DATA+\\where+PROBE_SNAPSHOT_Registers+PROBE_REG_{s}, %%{s}\n";
pub const SAVE_BEGIN = ".macro PROBE_SAVE where\nmovq %%rax, PROBE_DATA+\\where+PROBE_SNAPSHOT_Status\nmovq %%rdx, PROBE_DATA+\\where+PROBE_SNAPSHOT_Value\nmovq %%rdi, PROBE_DATA+\\where+PROBE_SNAPSHOT_Input\n";
pub const SAVE_REGISTER = "movq %%{s}, PROBE_DATA+\\where+PROBE_SNAPSHOT_Registers+PROBE_REG_{s}\n";
pub const SEED_END =
    \\fninit
    \\fldcw PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_Control
    \\fldl PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_X87+8
    \\fldl PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_X87
    \\movdqu PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_XMM0, %%xmm0
    \\movdqu PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_XMM15, %%xmm15
    \\ldmxcsr PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_MXCSR
    \\.endm
    \\
;
pub const SAVE_END =
    \\movq %%rsp, PROBE_DATA+\where+PROBE_SNAPSHOT_Stack
    \\pushfq
    \\popq %%rax
    \\movq %%rax, PROBE_DATA+\where+PROBE_SNAPSHOT_Flags
    \\fnstcw PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_Control
    \\fstpl PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_X87
    \\fstpl PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_X87+8
    \\movdqu %%xmm0, PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_XMM0
    \\movdqu %%xmm15, PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_XMM15
    \\stmxcsr PROBE_DATA+\where+PROBE_SNAPSHOT_Float+PROBE_FLOAT_MXCSR
    \\.endm
    \\
;
pub const BODY =
    \\PROBE_SEED PROBE_FRAME_FirstSeed
    \\std
    \\stc
    \\movq $0, %%rdi
    \\movq $PROBE_QUERY, %%rax
    \\int $0x80
    \\PROBE_SAVE PROBE_FRAME_Query
    \\PROBE_SEED PROBE_FRAME_SecondSeed
    \\std
    \\clc
    \\movq $0, %%rdi
    \\movq $PROBE_YIELD, %%rax
    \\int $0x80
    \\PROBE_SAVE PROBE_FRAME_Yield
    \\movq $1, PROBE_DATA+PROBE_FRAME_Finished
    \\cld
    \\1:
    \\movq $PROBE_YIELD, %%rax
    \\int $0x80
    \\jmp 1b
    \\.purgem PROBE_SEED
    \\.purgem PROBE_SAVE
    \\.global akiba_test_persona_end
    \\akiba_test_persona_end:
    \\
;
pub const STATUS = "Persona Query and scheduling Yield return exact status and value registers";
pub const REGISTERS = "Persona invocation returns preserve twelve independently seeded GPRs and input register";
pub const FLOAT = "Persona Query and Yield preserve distinct x87 SSE and MXCSR states";
pub const FLAGS = "Persona return flags preserve allowed carry and direction bits without privileged flags";
pub const STACK = "Persona returning invocations preserve the original user stack pointer";
pub const CLEANUP = "Persona state probe resumes its controller and releases every owned descriptor and completion";
