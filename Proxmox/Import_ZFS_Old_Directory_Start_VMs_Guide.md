
# 🧩 Guide to Import Old ZFS Storage and Start Old VMs in Proxmox

## 1. Import Old ZFS Pool into New Proxmox

If your ZFS pool is marked as _"was previously in use on another system"_, follow these steps:

### 📦 Install ZFS Utilities

```bash
apt update && apt install zfsutils-linux
```

### 🔍 Scan for ZFS Pools

```bash
zpool import
```

### 🚀 Import the Pool (Force If Needed)

```bash
zpool import -f <poolname>
```

### 🧪 Check Pool Status

```bash
zpool status
```

### 🔄 Enable Auto-Mount on Boot (Optional)

```bash
zpool set autoexpand=on <poolname>
zpool set autoreplace=on <poolname>
```

---

## 2. Add Old Directory to Proxmox

### 📁 Mount the Old Disk or Directory

```bash
mkdir -p /mnt/old_storage
mount /dev/sdX1 /mnt/old_storage
```

### 🛠️ Make Mount Persistent in `/etc/fstab`

```bash
/dev/sdX1  /mnt/old_storage  ext4  defaults  0  2
```

### ➕ Add Directory to Proxmox

In `/etc/pve/storage.cfg`:

```ini
dir: old-local
    path /mnt/old_storage
    content iso,backup,vztmpl,images
    maxfiles 5
```

Or via GUI: Datacenter > Storage > Add > Directory

---

## 3. Start Old VMs After Importing ZFS Pool

### 📂 List Available ZFS Datasets

```bash
zfs list
```

### 🔍 Check for VM Config Files

```bash
ls /etc/pve/qemu-server/
```

### 🛠️ Recreate VM Configs If Missing

```bash
qm create 100 --name restored-vm --memory 4096 --net0 virtio,bridge=vmbr0
qm set 100 --scsi0 <poolname>:vm-100-disk-0
```

### ▶️ Start the VM

```bash
qm start 100
```

### 🔧 Set Boot Order (Optional)

```bash
qm set 100 --boot order=scsi0
```

---

🧠 **Tips:**
- Always verify your disk/dataset names with `zfs list`
- If you have backups, you can use `qmrestore` instead
- Confirm that Proxmox node permissions and storage settings are correct

