//! Native Persona Entry And Invocation Assembly

const instructions = @import("personaasm").strings.invoke.instructions;

pub const SECTION = ".text.persona.entry";
pub const START = ".extern persona_main\ncallq persona_main\nud2";
pub const INVOKE = "movq %rdi, %rax\nmovq %rsi, %rdi\nmovq %rdx, %rsi\nmovq %rcx, %rdx\nmovq %r8, %r10\n" ++ instructions.CALL ++ "\nretq";
