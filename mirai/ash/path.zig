const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");

pub const PathError = error{
    NotFound,
    ReadFailed,
    InvalidPath,
};

pub const ResolvedPath = struct {
    cluster: u32,
    is_directory: bool,
};

pub fn resolve_path(fs: *afs.AFS(ahci.BlockDevice), current_cluster: u32, path: []const u8) PathError!ResolvedPath {
    if (path.len == 0) {
        return ResolvedPath{
            .cluster = current_cluster,
            .is_directory = true,
        };
    }

    var start_cluster: u32 = undefined;
    var path_start: usize = 0;

    if (path[0] == '/') {
        start_cluster = fs.root_cluster;
        path_start = 1;

        if (path.len == 1) {
            return ResolvedPath{
                .cluster = start_cluster,
                .is_directory = true,
            };
        }
    } else {
        start_cluster = current_cluster;
        path_start = 0;
    }

    var cluster = start_cluster;
    var is_dir = true;
    var i = path_start;

    while (i < path.len) {
        const component_start = i;
        while (i < path.len and path[i] != '/') : (i += 1) {}

        const component = path[component_start..i];

        if (component.len == 0) {
            if (i < path.len) i += 1;
            continue;
        }

        const entry = fs.find_file(cluster, component) orelse {
            return PathError.NotFound;
        };

        cluster = entry.first_cluster;
        is_dir = (entry.entry_type == afs.ENTRY_TYPE_DIR);

        if (i < path.len) i += 1;
    }

    return ResolvedPath{
        .cluster = cluster,
        .is_directory = is_dir,
    };
}
