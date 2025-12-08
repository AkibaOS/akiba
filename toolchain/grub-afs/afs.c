/* AFS (Akiba File System) driver for GRUB2 */

#include <grub/types.h>
#include <grub/misc.h>
#include <grub/mm.h>
#include <grub/err.h>
#include <grub/dl.h>
#include <grub/disk.h>
#include <grub/file.h>
#include <grub/fs.h>

GRUB_MOD_LICENSE("GPLv3+");

struct afs_boot_sector
{
  grub_uint8_t signature[8];
  grub_uint32_t version;
  grub_uint32_t bytes_per_sector;
  grub_uint32_t sectors_per_cluster;
  grub_uint32_t total_clusters;
  grub_uint32_t root_cluster;
  grub_uint32_t alloc_table_sector;
  grub_uint32_t alloc_table_size;
  grub_uint32_t data_area_sector;
  grub_uint8_t reserved[466];
  grub_uint16_t boot_signature;
} GRUB_PACKED;

struct afs_dir_entry
{
  grub_uint8_t entry_type;
  grub_uint8_t name_len;
  grub_uint8_t name[255];
  grub_uint8_t attributes;
  grub_uint16_t reserved;
  grub_uint32_t first_cluster;
  grub_uint64_t file_size;
  grub_uint64_t created_time;
  grub_uint64_t modified_time;
} GRUB_PACKED;

struct grub_afs_data
{
  grub_disk_t disk;
  grub_uint32_t partition_start;
  grub_uint32_t bytes_per_sector;
  grub_uint32_t sectors_per_cluster;
  grub_uint32_t root_cluster;
  grub_uint32_t alloc_table_sector;
  grub_uint32_t data_area_sector;
};

static grub_uint32_t
grub_afs_cluster_to_lba(struct grub_afs_data *data, grub_uint32_t cluster)
{
  return data->partition_start + data->data_area_sector + (cluster - 2) * data->sectors_per_cluster;
}

static grub_uint32_t
grub_afs_get_next_cluster(struct grub_afs_data *data, grub_uint32_t cluster)
{
  grub_uint32_t fat_entry;
  grub_uint32_t fat_sector = data->partition_start + data->alloc_table_sector + (cluster * 4) / 512;
  grub_uint32_t fat_offset = (cluster * 4) % 512;
  grub_uint8_t buffer[512];

  if (grub_disk_read(data->disk, fat_sector, 0, 512, buffer))
    return 0xFFFFFFFF;

  fat_entry = grub_le_to_cpu32(*(grub_uint32_t *)(buffer + fat_offset));
  return fat_entry;
}

static grub_err_t
grub_afs_find_file(struct grub_afs_data *data, grub_uint32_t dir_cluster, 
                   const char *name, struct afs_dir_entry *entry)
{
  grub_uint32_t cluster = dir_cluster;
  grub_uint8_t buffer[512];

  while (cluster != 0xFFFFFFFF)
    {
      grub_uint32_t lba = grub_afs_cluster_to_lba(data, cluster);
      
      for (grub_uint32_t sector = 0; sector < data->sectors_per_cluster; sector++)
        {
          if (grub_disk_read(data->disk, lba + sector, 0, 512, buffer))
            return grub_errno;

          // One entry per cluster at offset 0
          struct afs_dir_entry *e = (struct afs_dir_entry *)buffer;
          
          if (e->entry_type == 0x00)
            return grub_error(GRUB_ERR_FILE_NOT_FOUND, "file not found");
          
          if (e->entry_type == 0x01 || e->entry_type == 0x02)
            {
              if (e->name_len == grub_strlen(name) &&
                  grub_memcmp(e->name, name, e->name_len) == 0)
                {
                  grub_memcpy(entry, e, sizeof(struct afs_dir_entry));
                  return GRUB_ERR_NONE;
                }
            }
        }
      
      cluster = grub_afs_get_next_cluster(data, cluster);
    }

  return grub_error(GRUB_ERR_FILE_NOT_FOUND, "file not found");
}

static struct grub_afs_data *
grub_afs_mount(grub_disk_t disk)
{
  struct afs_boot_sector boot;
  struct grub_afs_data *data;

  if (grub_disk_read(disk, 0, 0, sizeof(boot), &boot))
    goto fail;

  if (grub_memcmp(boot.signature, "AKIBAFS!", 8) != 0)
    goto fail;

  if (grub_le_to_cpu16(boot.boot_signature) != 0xAA55)
    goto fail;

  data = grub_malloc(sizeof(struct grub_afs_data));
  if (!data)
    goto fail;

  data->disk = disk;
  data->partition_start = 0;
  data->bytes_per_sector = grub_le_to_cpu32(boot.bytes_per_sector);
  data->sectors_per_cluster = grub_le_to_cpu32(boot.sectors_per_cluster);
  data->root_cluster = grub_le_to_cpu32(boot.root_cluster);
  data->alloc_table_sector = grub_le_to_cpu32(boot.alloc_table_sector);
  data->data_area_sector = grub_le_to_cpu32(boot.data_area_sector);

  return data;

fail:
  grub_error(GRUB_ERR_BAD_FS, "not an AFS filesystem");
  return 0;
}

static grub_err_t
grub_afs_dir(grub_device_t device, const char *path,
             grub_fs_dir_hook_t hook, void *hook_data)
{
  struct grub_afs_data *data = grub_afs_mount(device->disk);
  grub_uint32_t cluster;
  grub_uint8_t buffer[512];
  struct afs_dir_entry dir_entry;

  if (!data)
    return grub_errno;

  // Start at root
  cluster = data->root_cluster;

  // Traverse path if not root
  if (path && path[0] != '\0' && !(path[0] == '/' && path[1] == '\0'))
    {
      const char *p = path;
      while (*p == '/') p++;

      while (*p)
        {
          char component[256];
          const char *next = p;
          grub_size_t len = 0;
          
          // Extract next path component
          while (*next && *next != '/')
            {
              if (len < 255)
                component[len++] = *next;
              next++;
            }
          component[len] = '\0';
          
          if (len > 0)
            {
              // Find this component in current directory
              if (grub_afs_find_file(data, cluster, component, &dir_entry))
                {
                  grub_free(data);
                  return grub_errno;
                }
              
              // Must be a directory
              if (dir_entry.entry_type != 0x02)
                {
                  grub_free(data);
                  return grub_error(GRUB_ERR_BAD_FILE_TYPE, "not a directory");
                }
              
              cluster = grub_le_to_cpu32(dir_entry.first_cluster);
            }
          
          p = next;
          while (*p == '/') p++;
        }
    }

  // Now list contents of the target directory
  while (cluster != 0xFFFFFFFF)
    {
      grub_uint32_t lba = grub_afs_cluster_to_lba(data, cluster);
      
      for (grub_uint32_t sector = 0; sector < data->sectors_per_cluster; sector++)
        {
          if (grub_disk_read(data->disk, lba + sector, 0, 512, buffer))
            {
              grub_free(data);
              return grub_errno;
            }

          // One entry per cluster at offset 0
          struct afs_dir_entry *e = (struct afs_dir_entry *)buffer;
          
          if (e->entry_type == 0x00)
            {
              grub_free(data);
              return GRUB_ERR_NONE;
            }
          
          if (e->entry_type == 0x01 || e->entry_type == 0x02)
            {
              struct grub_dirhook_info info;
              char name[256];
              
              grub_memset(&info, 0, sizeof(info));
              info.dir = (e->entry_type == 0x02);
              
              grub_memcpy(name, e->name, e->name_len);
              name[e->name_len] = '\0';
              
              if (hook(name, &info, hook_data))
                {
                  grub_free(data);
                  return GRUB_ERR_NONE;
                }
            }
        }
      
      cluster = grub_afs_get_next_cluster(data, cluster);
    }

  grub_free(data);
  return GRUB_ERR_NONE;
}

static grub_err_t
grub_afs_open(struct grub_file *file, const char *name)
{
  struct grub_afs_data *data;
  struct afs_dir_entry entry;
  char component[256];
  const char *p;
  grub_uint32_t current_cluster;
  int found_file = 0;

  data = grub_afs_mount(file->device->disk);
  if (!data)
    return grub_errno;

  current_cluster = data->root_cluster;
  p = name;
  
  while (*p == '/')
    p++;

  while (*p)
    {
      const char *next = p;
      grub_size_t len = 0;
      
      while (*next && *next != '/')
        {
          if (len < 255)
            component[len++] = *next;
          next++;
        }
      component[len] = '\0';
      
      if (len > 0)
        {
          if (grub_afs_find_file(data, current_cluster, component, &entry))
            {
              grub_free(data);
              return grub_errno;
            }
          current_cluster = grub_le_to_cpu32(entry.first_cluster);
          found_file = 1;
        }
      
      p = next;
      while (*p == '/')
        p++;
    }

  if (!found_file || entry.entry_type != 0x01)
    {
      grub_free(data);
      return grub_error(GRUB_ERR_BAD_FILE_TYPE, "not a regular file");
    }

  file->data = data;
  file->size = grub_le_to_cpu64(entry.file_size);
  
  return GRUB_ERR_NONE;
}

static grub_ssize_t
grub_afs_read(grub_file_t file, char *buf, grub_size_t len)
{
  struct grub_afs_data *data = file->data;
  grub_uint64_t pos = file->offset;
  grub_size_t bytes_read = 0;

  struct afs_dir_entry entry;
  char component[256];
  const char *p = file->name;
  grub_uint32_t current_cluster = data->root_cluster;

  while (*p == '/')
    p++;

  while (*p)
    {
      const char *next = p;
      grub_size_t clen = 0;
      
      while (*next && *next != '/')
        {
          if (clen < 255)
            component[clen++] = *next;
          next++;
        }
      component[clen] = '\0';
      
      if (clen > 0)
        {
          if (grub_afs_find_file(data, current_cluster, component, &entry))
            return -1;
          current_cluster = grub_le_to_cpu32(entry.first_cluster);
        }
      
      p = next;
      while (*p == '/')
        p++;
    }

  grub_uint32_t cluster = current_cluster;
  grub_uint32_t cluster_size = data->sectors_per_cluster * 512;
  grub_uint32_t skip_clusters = pos / cluster_size;
  grub_uint32_t cluster_offset = pos % cluster_size;

  for (grub_uint32_t i = 0; i < skip_clusters && cluster != 0xFFFFFFFF; i++)
    cluster = grub_afs_get_next_cluster(data, cluster);

  while (len > 0 && cluster != 0xFFFFFFFF)
    {
      grub_uint32_t lba = grub_afs_cluster_to_lba(data, cluster);
      grub_uint32_t to_read = cluster_size - cluster_offset;
      if (to_read > len)
        to_read = len;

      if (grub_disk_read(data->disk, lba, cluster_offset, to_read, buf))
        return -1;

      buf += to_read;
      len -= to_read;
      bytes_read += to_read;
      cluster_offset = 0;

      cluster = grub_afs_get_next_cluster(data, cluster);
    }

  return bytes_read;
}

static grub_err_t
grub_afs_close(grub_file_t file)
{
  grub_free(file->data);
  return GRUB_ERR_NONE;
}

static grub_err_t
grub_afs_label(grub_device_t device __attribute__((unused)), char **label)
{
  struct grub_afs_data *data;
  
  data = grub_afs_mount(device->disk);
  if (!data)
    return grub_errno;
  
  *label = grub_strdup("AKIBA");
  grub_free(data);
  
  return GRUB_ERR_NONE;
}

static struct grub_fs grub_afs_fs = {
  .name = "afs",
  .fs_dir = grub_afs_dir,
  .fs_open = grub_afs_open,
  .fs_read = grub_afs_read,
  .fs_close = grub_afs_close,
  .fs_label = grub_afs_label,
  .next = 0
};

GRUB_MOD_INIT(afs)
{
  grub_fs_register(&grub_afs_fs);
}

GRUB_MOD_FINI(afs)
{
  grub_fs_unregister(&grub_afs_fs);
}