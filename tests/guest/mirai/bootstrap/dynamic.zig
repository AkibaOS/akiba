//! Compiler Dynamic Persona And Shared Library Lifetime Checks

const bootstrap = @import("mirai").bootstrap;
const driver = @import("tests").guest.mirai.sensei.support;
const elf = @import("shared").elf;
const inputs = @import("tests").fixtures.constants.elf.layout;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const kernel = @import("mirai").memory.allocator.native;
const labels = @import("tests").guest.strings.elf;
const pmm = @import("mirai").pmm;
const stage = @import("tests").guest.mirai.bootstrap.stage;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;
const weaver = @import("weaver");

const Source = @import("tests").guest.types.elf.Source;

const PROGRAM = @embedFile("dynamicimage");
const LIBRARY = @embedFile("dynamiclibrary");

pub fn run() !void {
    const launcher = thread.state.getCurrent().?.Owner;
    const allocator = kernel.get();
    const baseline = user.state.ledger.count();
    const missing: Source = .{ .Library = null };
    const invalid: Source = .{ .Library = LIBRARY[0..1] };
    const missing_refused = if (weaver.library.load.collect.collect(allocator, stage.access(&missing), PROGRAM)) |graph| unexpected: {
        var unexpected_graph = graph;
        unexpected_graph.deinit();
        break :unexpected false;
    } else |failure| failure == error.LibraryNotFound;
    const invalid_refused = if (weaver.library.load.collect.collect(allocator, stage.access(&invalid), PROGRAM)) |graph| unexpected: {
        var unexpected_graph = graph;
        unexpected_graph.deinit();
        break :unexpected false;
    } else |failure| failure == error.InvalidHeader;
    verify.require(missing_refused and invalid_refused and user.state.ledger.count() == baseline, labels.DYNAMIC_REFUSAL);

    const source: Source = .{ .Library = LIBRARY };
    var graph = try weaver.library.load.collect.collect(allocator, stage.access(&source), PROGRAM);
    defer graph.deinit();
    if (graph.Libraries.len != 1) return error.InvalidFixture;
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    const biases: weaver.image.types.layout.Biases = .{ .Executable = inputs.DYNAMIC_EXECUTABLE_BIAS, .Libraries = &.{inputs.DYNAMIC_LIBRARY_BIAS} };
    var placed = try weaver.image.place.place(allocator, &graph, biases, policy, &.{.{
        .Start = inputs.STACK_ADDRESS - inputs.PAGE_BYTES,
        .End = inputs.STACK_ADDRESS + 2 * inputs.PAGE_BYTES,
    }});
    defer placed.deinit();
    var linked = try weaver.link.plan.plan(allocator, &placed);
    defer linked.deinit();
    const first = try stage.prepare(launcher, &linked, null);
    defer driver.dispose(first.ID) catch |failure| verify.failure(failure);
    const second = try stage.prepare(launcher, &linked, first.Owner);
    defer driver.dispose(second.ID) catch |failure| verify.failure(failure);

    const code = try stage.codeAddress(&placed.Libraries[0]);
    const counter = try stage.counterAddress(&placed.Libraries[0]);
    const first_code = kagami.extract.lookup(first.Owner.AddressSpace.?, code).?;
    const shared_code = kagami.extract.lookup(second.Owner.AddressSpace.?, code).?;
    const first_data = kagami.extract.lookup(first.Owner.AddressSpace.?, counter).?;
    const second_data = kagami.extract.lookup(second.Owner.AddressSpace.?, counter).?;
    const relro = placed.Executable.Relro orelse return error.InvalidFixture;
    const sealed = kagami.extract.lookup(second.Owner.AddressSpace.?, relro.Start).?;
    verify.require(first.Thread.Mode == .Persona and second.Thread.Mode == .Persona and
        first_code.PhysicalAddress == shared_code.PhysicalAddress and shared_code.Executable and !shared_code.Writable and
        first_data.PhysicalAddress != second_data.PhysicalAddress and second_data.Writable and !second_data.Executable and
        !sealed.Writable and !sealed.Executable, labels.DYNAMIC_MAPPINGS);

    const first_outcome = try finish(first);
    const retained = kagami.extract.lookup(second.Owner.AddressSpace.?, code).?;
    const counter_before = try stage.readCounter(second.Owner, counter);
    verify.require(first_outcome == inputs.DYNAMIC_RESULT and kata.state.findByID(first.ID) == null and
        retained.PhysicalAddress == shared_code.PhysicalAddress and pmm.state.isAllocated(retained.PhysicalAddress) and
        counter_before == inputs.DYNAMIC_COUNTER_INITIAL, labels.DYNAMIC_LIFETIME);

    const second_outcome = try finish(second);
    verify.require(second_outcome == inputs.DYNAMIC_RESULT and kata.state.findByID(second.ID) == null and
        !user.state.ledger.ownsPhysical(shared_code.PhysicalAddress) and !pmm.state.isAllocated(shared_code.PhysicalAddress) and
        user.state.ledger.count() == baseline, labels.DYNAMIC_EXECUTION);
}

fn finish(image: bootstrap.types.image.preparation.Prepared) !u64 {
    const identifier = try bootstrap.image.start.start(image);
    try driver.drain(identifier);
    const outcome = try kata.completion.lifetime.collect(identifier);
    return if (outcome == .Exited) outcome.Exited else error.InvalidFixture;
}
