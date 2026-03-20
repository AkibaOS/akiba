//! Render Operations

pub const banner = @import("banner.zig");
pub const exception = @import("exception.zig");
pub const context = @import("context.zig");
pub const stack = @import("stack.zig");
pub const memory = @import("memory.zig");
pub const modules = @import("modules.zig");

pub const ModuleInfo = modules.ModuleInfo;

pub const render_collapse_banner = banner.render;
pub const render_message = banner.render_message;
pub const render_halt_message = banner.render_halt;

pub const render_exception = exception.render;
pub const render_faulting_instruction = exception.render_faulting_instruction;

pub const render_context = context.render;

pub const render_stack_trace = stack.render;
pub const render_raw_stack = stack.render_raw_stack;

pub const render_memory = memory.render_around_address;
pub const render_instruction_bytes = memory.render_instruction_bytes;

pub const render_modules = modules.render;
pub const register_module = modules.register_module;
pub const find_module_for_address = modules.find_module_for_address;
