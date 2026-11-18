//! AFS Reader Initialization Rejection And Unwind Checks

const abort = @import("hikari").sequence.cleanup;
const afs = @import("shared").afs;
const claimtypes = @import("hikari").sequence.types.cleanup;
const inputs = @import("tests").constants.acquisition;
const fixture = @import("tests").guest.hikari.disk.fixture;
const labels = @import("tests").strings.acquisition;
const locator = @import("hikari").sequence.partition;
const media = @import("hikari").disk.types.media;
const partition = @import("hikari").sequence.types.partition;
const reader = @import("hikari").fs.types.afs.reader;
const verify = @import("tests").verify;

pub fn run() void {
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.FailAllocation = 2;
    verify.require(rejects(error.BTreeError, 2, 1, 2), labels.READER_ALLOCATION);
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.FailLBA = inputs.PARTITION_FIRST_LBA + 1;
    verify.require(rejects(error.ReadFailed, 1, 1, 2), labels.READER_READ);
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.Disk[inputs.PARTITION_FIRST_LBA * inputs.BLOCK_BYTES] ^= 1;
    const volume = rejects(error.InvalidVolumeHeader, 1, 1, 1);
    fixture.reset();
    fixture.encodeAFS();
    const descriptor = (inputs.PARTITION_FIRST_LBA + 1) * inputs.BLOCK_BYTES;
    fixture.device.Disk[descriptor + @offsetOf(afs.types.btree.NodeDescriptor, labels.NODE_TYPE_FIELD)] = 0xff;
    verify.require(volume and rejects(error.InvalidVolumeHeader, 1, 1, 2), labels.READER_HEADER);
    const discovery_rejected = replaceAfterDiscovery();
    const mount_rejected = replaceDuringMount();
    verify.require(discovery_rejected and mount_rejected, labels.READER_MEDIA);
    replaceAfterMount();
    discoveryRefusal();
    invalidDiscovery();
    largerCell();
}

fn replaceAfterDiscovery() bool {
    fixture.reset();
    fixture.encodeGPT();
    fixture.encodeAFS();
    var discovery: partition.Discovery = .{ .Parser = .{ .BootServices = &fixture.services } };
    defer if (!locator.deinitialize(&discovery)) verify.failure(error.ReleaseFailed);
    const acquired = (locator.findAfsPartition(&discovery) catch return false) orelse return false;
    const allocations = fixture.device.AllocateCalls;
    const reads = fixture.device.ReadCalls;
    fixture.media.MediaId += 1;
    var source: reader.Reader = .{ .BootServices = &fixture.services };
    const refused = if (source.initialize(acquired.Media, acquired.StartLBA, acquired.EndLBA)) |_| false else |failure| failure == error.ReadFailed;
    return source.deinitialize() and refused and fixture.device.AllocateCalls == allocations and fixture.device.ReadCalls == reads and fixture.clean();
}

fn replaceDuringMount() bool {
    fixture.reset();
    fixture.encodeAFS();
    var replacement = fixture.media;
    replacement.MediaId += 1;
    fixture.changeMediaAfterRead(inputs.PARTITION_FIRST_LBA, replacement);
    const volume_rejected = rejects(error.ReadFailed, 1, 1, 1);

    fixture.reset();
    fixture.encodeAFS();
    fixture.changeMediaAfterRead(inputs.PARTITION_FIRST_LBA + 1, replacement);
    const index_rejected = rejects(error.ReadFailed, 1, 1, 2);
    return volume_rejected and index_rejected;
}

fn replaceAfterMount() void {
    fixture.reset();
    fixture.encodeAFS();
    var source: reader.Reader = .{ .BootServices = &fixture.services };
    source.initialize(snapshot(), inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA) catch |failure| verify.failure(failure);
    const valid_leaf = (source.Index.readNode(1) catch |failure| verify.failure(failure)).isLeaf();
    const reads = fixture.device.ReadCalls;
    var replacement = fixture.media;
    replacement.MediaId += 1;
    fixture.changeMediaAfterRead(inputs.PARTITION_FIRST_LBA + 2, replacement);
    const during_read = if (source.Index.readNode(1)) |_| false else |failure| failure == error.ReadFailed;
    const before_read = if (source.Index.readNode(1)) |_| false else |failure| failure == error.ReadFailed;
    if (!source.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(valid_leaf and during_read and before_read and fixture.device.ReadCalls == reads + 1 and fixture.clean(), labels.BTREE_MEDIA);
}

fn discoveryRefusal() void {
    for (1..3) |position| {
        fixture.reset();
        fixture.encodeGPT();
        fixture.device.DiscoveryHandles = 2;
        fixture.device.FailFree = position;
        if (position == 2) fixture.device.FailLBA = inputs.TABLE_LBA;
        var claims: claimtypes.Claims = .{
            .Paging = .{ .BootServices = &fixture.services },
            .Discovery = .{ .Parser = .{ .BootServices = &fixture.services } },
        };
        const refused = if (locator.findAfsPartition(&claims.Discovery.?)) |_| false else |failure| failure == error.ReleaseFailed;
        const parser = &claims.Discovery.?.Parser;
        const retained = parser.Scratch.Pool.Allocation != null and claims.Discovery.?.Handles.Allocation != null and parser.EntriesCount == 0 and
            fixture.device.ReadCalls == position and fixture.device.FreeCalls == position and fixture.live() == 2;
        const recovered = abort.finish(&claims) and abort.finish(&claims);
        verify.require(refused and retained and recovered and claims.Discovery == null and
            fixture.device.ReadCalls == position and fixture.device.FreeCalls == position + 2 and fixture.clean(), labels.DISCOVERY_STOPS);
    }
}

fn invalidDiscovery() void {
    fixture.reset();
    fixture.device.DiscoveryHandles = 0;
    var claims: claimtypes.Claims = .{
        .Paging = .{ .BootServices = &fixture.services },
        .Discovery = .{ .Parser = .{ .BootServices = &fixture.services } },
    };
    const rejected = if (locator.findAfsPartition(&claims.Discovery.?)) |_| false else |failure| failure == error.InvalidFirmwareReply;
    const incomplete = !abort.finish(&claims);
    verify.require(rejected and incomplete and claims.Discovery != null and claims.Discovery.?.Handles.Untrusted and
        claims.Discovery.?.Handles.Allocation == null and fixture.device.AllocateCalls == 0 and fixture.device.FreeCalls == 0 and
        fixture.device.ReadCalls == 0 and fixture.clean(), labels.DISCOVERY_REPLY);
}

fn largerCell() void {
    const cell_size = 2 * inputs.BLOCK_BYTES;
    const index_lba = inputs.PARTITION_FIRST_LBA + cell_size / inputs.BLOCK_BYTES;
    fixture.reset();
    fixture.encodeAfsGeometry(cell_size);
    fixture.device.FailFree = 1;
    var early: reader.Reader = .{ .BootServices = &fixture.services };
    const refused = if (early.initialize(snapshot(), inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA)) |_| false else |failure| failure == error.ReleaseFailed;
    const retained = early.CellAllocation.Pool.Allocation != null and early.CellAllocation.Size == inputs.BLOCK_BYTES and
        early.CellSize == 0 and early.NodeAllocation.isEmpty() and fixture.device.AllocateCalls == 1 and fixture.device.ReadCalls == 1;
    const closed = if (early.Index.readNode(0)) |_| false else |failure| failure == error.InvalidNode;
    const recovered = early.deinitialize() and early.deinitialize();
    verify.require(refused and retained and closed and recovered and fixture.device.FreeCalls == 2 and fixture.clean(), labels.READER_GROW_REFUSAL);

    fixture.reset();
    fixture.encodeAfsGeometry(cell_size);
    var mounted: reader.Reader = .{ .BootServices = &fixture.services };
    mounted.initialize(snapshot(), inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA) catch |failure| verify.failure(failure);
    const original = mounted.Index.readNode(1) catch |failure| verify.failure(failure);
    const copied = original.isLeaf() and original.Height == 1 and fixture.device.ReadCalls == 3 and
        fixture.device.Reads[2].LBA == index_lba and fixture.device.Reads[2].Bytes == cell_size and
        fixture.device.Reads[2].Address == fixture.device.Reads[1].Address and
        @intFromPtr(mounted.CellAllocation.Pool.Allocation.?) != @intFromPtr(mounted.CellAllocation.Data);
    const leaf_offset = index_lba * inputs.BLOCK_BYTES + inputs.BLOCK_BYTES;
    const leaf: *align(1) afs.types.btree.NodeDescriptor = @ptrCast(&fixture.device.Disk[leaf_offset]);
    leaf.Height = 2;
    var replacement = fixture.media;
    replacement.MediaId += 1;
    fixture.changeMediaAfterRead(index_lba, replacement);
    const rejected = if (mounted.Index.readNode(1)) |_| false else |failure| failure == error.ReadFailed;
    const stable = rejected and original.Height == 1 and fixture.device.ReadCalls == 4 and fixture.device.AllocateCalls == 3 and
        fixture.device.FreeCalls == 1 and fixture.live() == 2;
    const cleaned = mounted.deinitialize();
    verify.require(copied and stable and cleaned and fixture.clean(), labels.READER_SHARED_CELL);
}

fn snapshot() media.MediaSnapshot {
    return media.MediaSnapshot.capture(&fixture.protocol) orelse verify.failure(error.NoMedia);
}

fn rejects(expected: anyerror, allocations: usize, frees: usize, reads: usize) bool {
    var source: reader.Reader = .{ .BootServices = &fixture.services };
    const refused = if (source.initialize(snapshot(), inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA)) |_| false else |failure| failure == expected;
    return source.deinitialize() and refused and fixture.device.AllocateCalls == allocations and fixture.device.FreeCalls == frees and
        fixture.device.ReadCalls == reads and fixture.clean();
}
