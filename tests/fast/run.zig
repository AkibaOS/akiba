//! AFS Bounds Test Entry

const afs = @import("tests").fast.shared.afs;

test "AFS spans fit entirely inside the volume" {
    try afs.bounds.spanBounds();
}

test "AFS span checks reject overflowing ends" {
    try afs.bounds.spanOverflow();
}

test "AFS cell LBAs honor inclusive endpoints" {
    try afs.bounds.inclusiveEndpoints();
}

test "AFS cell LBAs reject invalid geometry" {
    try afs.bounds.invalidGeometry();
}

test "AFS cell reads reject truncation" {
    try afs.bounds.truncatedReads();
}

test "AFS cell LBAs guard large offsets" {
    try afs.bounds.largeOffsets();
}

test "AFS headers validate signature and version" {
    try afs.bounds.signatureAndVersion();
}

test "AFS header cell sizes respect supported boundaries" {
    try afs.bounds.cellSizeBoundaries();
}
