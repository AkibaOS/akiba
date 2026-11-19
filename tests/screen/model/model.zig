//! Diagnostic Check Progress And Scrolling Viewport

const std = @import("std");

const text = @import("tests").screen.strings.text;
const types = @import("tests").screen.types.model;

pub fn initialize(rows: []types.Row, total: usize) types.Model {
    var state: types.Model = .{ .Rows = rows, .Total = total };
    append(&state, .{ .Kind = .Info, .Text = text.STARTING });
    return state;
}

pub fn begin(state: *types.Model, name: []const u8) bool {
    if (state.Done or state.Active != null or state.Completed >= state.Total or name.len == 0) return false;
    state.Active = name;
    state.TailIsPassEvidence = false;
    return true;
}

pub fn beginWork(state: *types.Model, total: usize) bool {
    if (state.Active == null or state.ActiveVerified != null or total == 0) return false;
    state.ActiveTotal = total;
    state.ActiveVerified = 0;
    return true;
}

pub fn checkpoint(state: *types.Model, verified: usize) bool {
    const before = state.ActiveVerified orelse 0;
    if (state.Active == null or verified <= before) return false;
    if (state.ActiveTotal) |total| {
        if (verified > total or verified - before != 1) return false;
    }
    state.ActiveVerified = verified;
    return true;
}

pub fn finish(state: *types.Model, outcome: types.Outcome) bool {
    const name = state.Active orelse return false;
    if (outcome == .Pass and state.ActiveTotal != null and state.ActiveVerified != state.ActiveTotal) return false;
    return closeActive(state, outcome, name);
}

pub fn fail(state: *types.Model, detail: []const u8) bool {
    const name = state.Active orelse return false;
    return closeActive(state, .Fail, if (detail.len == 0) name else detail);
}

fn closeActive(state: *types.Model, outcome: types.Outcome, name: []const u8) bool {
    state.Active = null;
    state.Completed += 1;
    if (outcome == .Fail) state.Failed += 1;
    append(state, .{ .Kind = if (outcome == .Pass) .Pass else .Fail, .Text = name, .Verified = state.ActiveVerified });
    state.ActiveVerified = null;
    state.ActiveTotal = null;
    return true;
}

pub fn evidence(state: *types.Model, outcome: types.Outcome, name: []const u8) void {
    if (state.Active == null or name.len == 0) return;
    if (outcome == .Pass and state.TailIsPassEvidence and state.Count != 0) {
        const last = &state.Rows[wrap(state.Oldest, state.Count - 1, state.Rows.len)];
        if (std.mem.eql(u8, last.Text, name)) {
            last.Repeats +|= 1;
            return;
        }
    }
    append(state, .{ .Kind = if (outcome == .Pass) .Pass else .Fail, .Text = name });
    state.TailIsPassEvidence = outcome == .Pass;
}

pub fn recall(state: *types.Model, entry: types.Row) void {
    if (!state.Done and state.Active == null and entry.Kind != .Running) append(state, entry);
}

pub fn complete(state: *types.Model) bool {
    return state.Total != 0 and state.Completed == state.Total and endPhase(state);
}

pub fn endPhase(state: *types.Model) bool {
    if (state.Done or state.Active != null) return false;
    state.Done = true;
    append(state, .{ .Kind = .Info, .Text = text.COMPLETED });
    return true;
}

pub fn percent(state: *const types.Model) usize {
    return scaled(state, 100);
}

pub fn scaled(state: *const types.Model, scale: usize) usize {
    if (state.Total == 0 or scale == 0) return 0;
    const partial = if (state.ActiveTotal) |total|
        @min(scale - 1, @as(u128, state.ActiveVerified orelse 0) * scale / total)
    else
        0;
    return @intCast((@as(u128, state.Completed) * scale + partial) / state.Total);
}

pub fn activeIndex(state: *const types.Model) ?usize {
    if (state.Active == null or state.Rows.len == 0) return null;
    return @min(state.Count, state.Rows.len - 1);
}

pub fn row(state: *const types.Model, index: usize) ?types.Row {
    const active = state.Active != null;
    const visible = state.Count + @intFromBool(active and state.Count < state.Rows.len);
    if (index >= visible) return null;
    if (active and index == visible - 1) return .{ .Kind = .Running, .Text = state.Active.?, .Verified = state.ActiveVerified };
    const skipped = state.Count - (visible - @intFromBool(active));
    return state.Rows[wrap(state.Oldest, skipped + index, state.Rows.len)];
}

fn append(state: *types.Model, entry: types.Row) void {
    state.TailIsPassEvidence = false;
    const capacity = state.Rows.len;
    if (capacity == 0) return;
    if (state.Count == capacity) {
        state.Rows[state.Oldest] = entry;
        state.Oldest = wrap(state.Oldest, 1, capacity);
    } else {
        state.Rows[wrap(state.Oldest, state.Count, capacity)] = entry;
        state.Count += 1;
    }
}

fn wrap(start: usize, offset: usize, capacity: usize) usize {
    const remaining = capacity - start;
    return if (offset < remaining) start + offset else offset - remaining;
}
