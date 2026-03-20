//! Recovery Operations

pub const resume_mod = @import("resume.zig");
pub const skip = @import("skip.zig");
pub const terminate = @import("terminate.zig");

pub const resume_execution = resume_mod.resume_execution;
pub const resume_with_new_context = resume_mod.resume_with_new_context;
pub const can_resume = resume_mod.can_resume;

pub const skip_instruction = skip.skip_instruction;
pub const can_skip = skip.can_skip;

pub const terminate_kata = terminate.terminate;
pub const terminate_with_corpse = terminate.terminate_with_corpse;
pub const is_last_thread = terminate.is_last_thread;
