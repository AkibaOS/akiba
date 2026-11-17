//! Disposable Root Policy Regressions

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const physical = try pmm.allocate.single.allocatePage();
    defer pmm.free.single.freePage(physical);
    const root = try kagami.create.create();
    defer _ = kagami.destroy.destroy(root);
    const before = pmm.state.getStatistics();
    for (inputs.MAP_REJECTIONS) |fixture| {
        var rejected = false;
        kagami.enter.enter(root, fixture.Address, physical + fixture.PhysicalOffset, fixture.Protection) catch |failure| {
            rejected = failure == fixture.Failure;
        };
        verify.require(rejected and root.TablePages == 1 and root.ResidentPages == 0 and root.WiredPages == 0 and
            kagami.extract.lookup(root, inputs.MAP_ADDRESS) == null and
            std.meta.eql(before, pmm.state.getStatistics()), labels.KAGAMI_REJECTIONS);
    }
}
