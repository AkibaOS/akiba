//! Verify Nested Installed Members Through The Live AFS Service

const std = @import("std");

const codec = @import("shared").afs.service.request;
const copy = @import("mirai").user.copy.transfer;
const fixtures = @import("tests").fixtures.strings.bundle;
const harness = @import("tests").guest.postman.harness;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.ahci.bundle;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;
const locations = @import("tests").guest.constants.postman.transport;
const memory = @import("mirai").user.memory;
const timing = @import("tests").fixtures.constants.service;
const verify = @import("tests").guest.support.verify;
const witness = @import("tests").guest.constants.ahci.fixture;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Call = @import("shared").persona.types.call.Call;
const Entry = @import("shared").afs.types.read.list.Entry;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

const IMAGE = @embedFile("dynamicimage");

pub fn prove(pulse: u64, endpoint: u64) !void {
    const owner = kata.state.findByID(pulse) orelse return WitnessError.InvalidBundleReply;
    var actor = try harness.attach(.{
        .Owner = owner,
        .ID = pulse,
        .Code = witness.BUNDLE_CODE,
        .Data = witness.BUNDLE_DATA,
        .Stack = witness.BUNDLE_STACK,
    });
    try memory.allocate.allocate(owner, witness.BUNDLE_REPLY);
    try memory.finalize.finalize(owner, witness.BUNDLE_REPLY, .ReadWrite);
    const chunks = (IMAGE.len + limits.MAX_PAYLOAD_BYTES - 1) / limits.MAX_PAYLOAD_BYTES;
    const steps = 6 + chunks;
    try harness.install(&actor, &([_]@TypeOf(harness.call(&actor)){harness.call(&actor)} ** steps));

    var output: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var step: usize = 1;
    try exchange(&actor, endpoint, step, letters.LIST, fixtures.CHECK_PARENT, 0, 0, letters.ENTRY, output[0..@sizeOf(Entry)]);
    try expectEntry(output[0..@sizeOf(Entry)], fixtures.BINARY_MEMBER);
    step += 1;
    try exchange(&actor, endpoint, step, letters.LIST, fixtures.CHECK_PARENT, 1, 0, letters.ENTRY, output[0..@sizeOf(Entry)]);
    try expectEntry(output[0..@sizeOf(Entry)], fixtures.MANIFEST_MEMBER);
    step += 1;
    try exchange(&actor, endpoint, step, letters.LIST, fixtures.CHECK_PARENT, 2, 0, letters.END, output[0..0]);
    step += 1;
    try exchange(&actor, endpoint, step, letters.READ, fixtures.CHECK_MANIFEST, 0, fixtures.DESCRIPTOR.len, letters.DATA, output[0..fixtures.DESCRIPTOR.len]);
    if (!std.mem.eql(u8, output[0..fixtures.DESCRIPTOR.len], fixtures.DESCRIPTOR)) return WitnessError.InvalidBundleReply;
    step += 1;
    try exchange(&actor, endpoint, step, letters.STAT, fixtures.CHECK_BINARY, 0, 0, letters.SIZE, output[0..@sizeOf(u64)]);
    if (std.mem.readInt(u64, output[0..@sizeOf(u64)], .little) != IMAGE.len) return WitnessError.InvalidBundleReply;
    var offset: usize = 0;
    while (offset < IMAGE.len) : (offset += limits.MAX_PAYLOAD_BYTES) {
        step += 1;
        const count = @min(IMAGE.len - offset, output.len);
        try exchange(&actor, endpoint, step, letters.READ, fixtures.CHECK_BINARY, offset, count, letters.DATA, output[0..count]);
        if (!std.mem.eql(u8, output[0..count], IMAGE[offset..][0..count])) return WitnessError.InvalidBundleReply;
    }
    step += 1;
    try exchange(&actor, endpoint, step, letters.STAT, fixtures.CHECK_MISSING, 0, 0, letters.MISSING, output[0..0]);
    try harness.advance(&actor, step);
    verify.require(true, labels.NESTED);
}

fn exchange(actor: *Actor, endpoint: u64, step: usize, operation: u64, path: []const u8, offset: usize, count: usize, expected: u64, output: []u8) !void {
    var message: [locations.OUTPUT_OFFSET - locations.INPUT_OFFSET]u8 = undefined;
    const encoded = codec.encode(&message, path, offset, count) orelse return WitnessError.InvalidBundleReply;
    try harness.input(actor, encoded);
    const descriptor: Call = .{
        .Destination = endpoint,
        .Type = operation,
        .Request = actor.Data + locations.INPUT_OFFSET,
        .RequestLength = encoded.len,
        .Reply = witness.BUNDLE_REPLY,
        .ReplyCapacity = output.len,
        .Metadata = actor.Data + locations.HEADER_OFFSET,
    };
    try copy.write(actor.Owner, actor.Data + locations.CALL_OFFSET, std.mem.asBytes(&descriptor));
    if (step == 1) try harness.start(actor) else try harness.advance(actor, step - 1);
    try harness.waitTimedStep(actor, step, timing.TIMEOUT_TICKS);
    const header = try harness.header(actor);
    if (!try harness.resultIs(actor, step, .Success, output.len) or header.Sender != endpoint or
        header.Type != expected or header.Length != output.len or header.ReplyTicket != 0) return WitnessError.InvalidBundleReply;
    if (output.len != 0) try copy.read(actor.Owner, output, witness.BUNDLE_REPLY);
}

fn expectEntry(bytes: *const [@sizeOf(Entry)]u8, name: []const u8) !void {
    const entry = std.mem.bytesToValue(Entry, bytes);
    if (entry.Kind != .Unit or entry.Length != name.len) return WitnessError.InvalidBundleReply;
    for (name, entry.Identity[0..entry.Length]) |expected, actual| {
        if (actual != expected) return WitnessError.InvalidBundleReply;
    }
}
