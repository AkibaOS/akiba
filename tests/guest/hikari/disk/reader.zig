//! AFS Reader Initialization Rejection And Unwind Checks

const afs = @import("shared").afs;
const inputs = @import("tests").constants.acquisition;
const fixture = @import("tests").guest.hikari.disk.fixture;
const labels = @import("tests").strings.acquisition;
const locator = @import("hikari").sequence.partition;
const media = @import("hikari").disk.types.media;
const reader = @import("hikari").fs.types.afs.reader;
const verify = @import("tests").verify;

pub fn run() void {
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.FailAllocation = 4;
    verify.require(rejects(error.BTreeError, 4, 3, 2), labels.READER_ALLOCATION);
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.FailLBA = inputs.PARTITION_FIRST_LBA + 1;
    verify.require(rejects(error.ReadFailed, 3, 3, 2), labels.READER_READ);
    fixture.reset();
    fixture.encodeAFS();
    fixture.device.Disk[inputs.PARTITION_FIRST_LBA * inputs.BLOCK_BYTES] ^= 1;
    const volume = rejects(error.InvalidVolumeHeader, 1, 1, 1);
    fixture.reset();
    fixture.encodeAFS();
    const descriptor = (inputs.PARTITION_FIRST_LBA + 1) * inputs.BLOCK_BYTES;
    fixture.device.Disk[descriptor + @offsetOf(afs.types.btree.NodeDescriptor, labels.NODE_TYPE_FIELD)] = 0xff;
    verify.require(volume and rejects(error.InvalidVolumeHeader, 3, 3, 2), labels.READER_HEADER);
    const discovery_rejected = replaceAfterDiscovery();
    const mount_rejected = replaceDuringMount();
    verify.require(discovery_rejected and mount_rejected, labels.READER_MEDIA);
    replaceAfterMount();
}

fn replaceAfterDiscovery() bool {
    fixture.reset();
    fixture.encodeGPT();
    fixture.encodeAFS();
    const acquired = locator.findAfsPartition(&fixture.services) orelse return false;
    const allocations = fixture.device.AllocateCalls;
    const reads = fixture.device.ReadCalls;
    fixture.media.MediaId += 1;
    var source = reader.Reader.initialize(acquired.Media, &fixture.services, acquired.StartLBA, acquired.EndLBA) catch |failure| {
        return failure == error.ReadFailed and fixture.device.AllocateCalls == allocations and
            fixture.device.ReadCalls == reads and fixture.clean();
    };
    source.deinitialize();
    return false;
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
    const index_rejected = rejects(error.ReadFailed, 3, 3, 2);
    return volume_rejected and index_rejected;
}

fn replaceAfterMount() void {
    fixture.reset();
    fixture.encodeAFS();
    var source = reader.Reader.initialize(snapshot(), &fixture.services, inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA) catch |failure| verify.failure(failure);
    const valid_leaf = (source.Index.readNode(1) catch |failure| verify.failure(failure)).isLeaf();
    const reads = fixture.device.ReadCalls;
    var replacement = fixture.media;
    replacement.MediaId += 1;
    fixture.changeMediaAfterRead(inputs.PARTITION_FIRST_LBA + 2, replacement);
    const during_read = if (source.Index.readNode(1)) |_| false else |failure| failure == error.ReadFailed;
    const before_read = if (source.Index.readNode(1)) |_| false else |failure| failure == error.ReadFailed;
    source.deinitialize();
    verify.require(valid_leaf and during_read and before_read and fixture.device.ReadCalls == reads + 1 and fixture.clean(), labels.BTREE_MEDIA);
}

fn snapshot() media.MediaSnapshot {
    return media.MediaSnapshot.capture(&fixture.protocol) orelse verify.failure(error.NoMedia);
}

fn rejects(expected: anyerror, allocations: usize, frees: usize, reads: usize) bool {
    var source = reader.Reader.initialize(snapshot(), &fixture.services, inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA) catch |failure| {
        return failure == expected and fixture.device.AllocateCalls == allocations and fixture.device.FreeCalls == frees and
            fixture.device.ReadCalls == reads and fixture.clean();
    };
    source.deinitialize();
    return false;
}
