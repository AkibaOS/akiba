//! Diagnostic Check Progress And Scrolling Viewport

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
    return true;
}

pub fn finish(state: *types.Model, outcome: types.Outcome) bool {
    const name = state.Active orelse return false;
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
    append(state, .{ .Kind = if (outcome == .Pass) .Pass else .Fail, .Text = name });
    return true;
}

pub fn evidence(state: *types.Model, outcome: types.Outcome, name: []const u8) void {
    if (state.Active == null or name.len == 0) return;
    append(state, .{ .Kind = if (outcome == .Pass) .Pass else .Fail, .Text = name });
}

pub fn complete(state: *types.Model) bool {
    if (state.Done or state.Active != null or state.Total == 0 or state.Completed != state.Total) return false;
    state.Done = true;
    append(state, .{ .Kind = .Info, .Text = text.COMPLETED });
    return true;
}

pub fn percent(state: *const types.Model) usize {
    if (state.Total == 0) return 0;
    return @intCast(@as(u128, state.Completed) * 100 / state.Total);
}

pub fn row(state: *const types.Model, index: usize) ?types.Row {
    const active = state.Active != null;
    const visible = state.Count + @intFromBool(active and state.Count < state.Rows.len);
    if (index >= visible) return null;
    if (active and index == visible - 1) return .{ .Kind = .Running, .Text = state.Active.? };
    const skipped = state.Count - (visible - @intFromBool(active));
    return state.Rows[wrap(state.Oldest, skipped + index, state.Rows.len)];
}

fn append(state: *types.Model, entry: types.Row) void {
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
