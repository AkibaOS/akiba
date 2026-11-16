//! Windows Owned Process Containment

const std = @import("std");

const limits = @import("checks").constants.runner;
const types = @import("checks").types.windows;

const HANDLE = std.os.windows.HANDLE;
const BOOL = std.os.windows.BOOL;

extern "kernel32" fn CreateJobObjectW(?*anyopaque, ?[*:0]const u16) callconv(.winapi) ?HANDLE;
extern "kernel32" fn SetInformationJobObject(HANDLE, c_int, *const anyopaque, u32) callconv(.winapi) BOOL;
extern "kernel32" fn AssignProcessToJobObject(HANDLE, HANDLE) callconv(.winapi) BOOL;
extern "kernel32" fn TerminateJobObject(HANDLE, u32) callconv(.winapi) BOOL;
extern "kernel32" fn QueryInformationJobObject(HANDLE, c_int, *anyopaque, u32, ?*u32) callconv(.winapi) BOOL;
extern "kernel32" fn ResumeThread(HANDLE) callconv(.winapi) u32;
extern "kernel32" fn SetConsoleCtrlHandler(?types.ControlHandler, BOOL) callconv(.winapi) BOOL;

var interrupted: std.atomic.Value(bool) = .init(false);

fn onControl(event: u32) callconv(.winapi) BOOL {
    if (event != limits.CONSOLE_INTERRUPT and event != limits.CONSOLE_BREAK) return 0;
    interrupted.store(true, .monotonic);
    return 1;
}

pub fn install() !void {
    interrupted.store(false, .monotonic);
    if (SetConsoleCtrlHandler(&onControl, 1) == 0) return error.ConsoleHandlerFailed;
}

pub fn restore() void {
    _ = SetConsoleCtrlHandler(&onControl, 0);
}

pub fn cancelled() bool {
    return interrupted.load(.monotonic);
}

pub fn create() !HANDLE {
    const job = CreateJobObjectW(null, null) orelse return error.ProcessContainmentFailed;
    errdefer std.os.windows.CloseHandle(job);
    var information: types.ExtendedLimits = .{};
    information.Basic.Flags = limits.JOB_KILL_ON_CLOSE;
    if (SetInformationJobObject(job, limits.JOB_EXTENDED_LIMITS, &information, @sizeOf(types.ExtendedLimits)) == 0)
        return error.ProcessContainmentFailed;
    return job;
}

pub fn assign(job: HANDLE, child: *std.process.Child) !void {
    if (AssignProcessToJobObject(job, child.id) == 0) return error.ProcessContainmentFailed;
}

pub fn resumeThread(child: *std.process.Child) !void {
    if (ResumeThread(child.thread_handle) == limits.RESUME_FAILED) return error.ProcessContainmentFailed;
}

pub fn exited(child: *const std.process.Child) !bool {
    const result = std.os.windows.kernel32.WaitForSingleObject(child.id, 0);
    return switch (result) {
        limits.WAIT_SIGNALED => true,
        limits.WAIT_TIMEOUT => false,
        else => error.ProcessWaitFailed,
    };
}

pub fn terminate(job: HANDLE) !void {
    if (TerminateJobObject(job, 1) == 0) return error.ProcessContainmentFailed;
}

pub fn empty(job: HANDLE) !bool {
    var information: types.Accounting = .{};
    if (QueryInformationJobObject(job, limits.JOB_ACCOUNTING, &information, @sizeOf(types.Accounting), null) == 0)
        return error.ProcessContainmentFailed;
    return information.ActiveProcesses == 0;
}

pub fn close(job: HANDLE) void {
    std.os.windows.CloseHandle(job);
}
