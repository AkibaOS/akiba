//! AFS Reader Initialization Rejection And Unwind Checks

const afs = @import("shared").afs;
const inputs = @import("tests").constants.acquisition;
const fixture = @import("tests").guest.hikari.disk.fixture;
const labels = @import("tests").strings.acquisition;
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
}

fn rejects(expected: anyerror, allocations: usize, frees: usize, reads: usize) bool {
    var source = reader.Reader.initialize(&fixture.protocol, &fixture.services, inputs.PARTITION_FIRST_LBA, inputs.PARTITION_LAST_LBA) catch |failure| {
        return failure == expected and fixture.device.AllocateCalls == allocations and fixture.device.FreeCalls == frees and
            fixture.device.ReadCalls == reads and fixture.clean();
    };
    source.deinitialize();
    return false;
}
