//! Scheduler Admission And Retirement Regressions

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.sensei;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const verify = @import("tests").verify;

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}

pub fn run() !void {
    const owner = try kata.create.create();
    const owner_id = owner.ID;
    defer support.dispose(owner_id) catch |failure| verify.failure(failure);
    const first = try thread.create.create(owner, entry, null);
    const second = try thread.create.create(owner, entry, null);
    var registered: u16 = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        const scheduler = sensei.state.getState();
        registered = scheduler.RegisteredCount;
        const ready = scheduler.Ready.Count;
        try sensei.control.start(first);
        try sensei.control.start(second);
        const first_record = sensei.registry.find(first).?;
        const second_record = sensei.registry.find(second).?;
        verify.require(first_record.Queue == &scheduler.Ready and first_record.Next == second_record and
            second_record.Queue == &scheduler.Ready and second_record.Next == null and scheduler.Ready.Tail == second_record and
            scheduler.Ready.Count == ready + 2 and scheduler.RegisteredCount == registered + 2 and
            first.Managed and first.Admitted and first.Status == .Ready and second.Managed and second.Admitted and
            second.Status == .Ready and owner.LiveThreadCount == 2, labels.ADMISSION_FIFO);
        var duplicate = false;
        sensei.control.start(first) catch |failure| {
            duplicate = failure == error.AlreadyManaged;
        };
        verify.require(duplicate and scheduler.Ready.Count == ready + 2 and
            scheduler.RegisteredCount == registered + 2 and first_record.Next == second_record, labels.ADMISSION_DUPLICATE);
        try sensei.control.detach(first);
        verify.require(!first.Managed and first.Status == .Stopped and sensei.registry.find(first) == null and
            owner.LiveThreadCount == 1 and scheduler.Ready.Count == ready + 1 and
            scheduler.RegisteredCount == registered + 1, labels.DETACH);
        var duplicate_detach = false;
        sensei.control.detach(first) catch |failure| {
            duplicate_detach = failure == error.NotManaged;
        };
        var last_detach = false;
        sensei.control.detach(second) catch |failure| {
            last_detach = failure == error.InUse;
        };
        verify.require(duplicate_detach and last_detach and second.Managed and second.Status == .Ready and
            second_record.Queue == &scheduler.Ready and scheduler.Ready.Count == ready + 1 and
            scheduler.RegisteredCount == registered + 1, labels.DETACH_REJECTION);
        try thread.destroy.destroy(first);
    }
    try support.drain(owner_id);
    const flags = guard.acquire();
    defer guard.release(flags);
    const completed = if (kata.completion.lifetime.peek(owner_id)) |outcome| outcome == .Completed else false;
    try support.dispose(owner_id);
    verify.require(completed and !thread.state.owns(first) and !thread.state.owns(second) and
        sensei.registry.find(first) == null and sensei.registry.find(second) == null and
        kata.state.findByID(owner_id) == null and kata.completion.storage.ownerOf(owner_id) == null and
        sensei.state.getState().RegisteredCount == registered, labels.RETIREMENT);
}
