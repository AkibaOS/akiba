//! Forced Semantic Analysis

const analysis = @import("utils").analysis;

const limits = analysis.constants.limits;

pub fn all(comptime namespace: type) void {
    @setEvalBranchQuota(limits.EVALUATION_QUOTA);
    walk(namespace, limits.MAX_DEPTH);
}

fn walk(comptime namespace: type, comptime depth: u8) void {
    if (depth == 0) {
        return;
    }

    switch (@typeInfo(namespace)) {
        .@"struct" => {},
        else => return,
    }

    inline for (@typeInfo(namespace).@"struct".decls) |declaration| {
        if (@TypeOf(@field(namespace, declaration.name)) == type) {
            walk(@field(namespace, declaration.name), depth - 1);
            continue;
        }

        _ = &@field(namespace, declaration.name);
    }
}
