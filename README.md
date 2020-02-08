## Credit
Originally Developed by MatrixAI.


## Installation

Download the minimal installation CD 64 bit: https://nixos.org/nixos/download.html

Load it onto USB.

Boot into the installation ISO.

Connect to the internet.

```sh
iw wlp6s0 scan
wpa_supplicant -B -i wlp6s0 -c <(wpa_passphrase 'SSID' '*********')
```

You can use SSH instead of typing this in at the terminal.

```sh
# set the root password
passwd
systemctl start sshd
# ssh in via root@IP
ip addr
```

### Setup Filesystem

```sh
# set inside /etc/nixos/configuration.nix (we need ZFS)
# boot.supportedFilesystems = [ "zfs" ];
nixos-rebuild switch

did = "xxx"

sgdisk --zap-all /dev/disk/by-id/$did

sgdisk -n 1:0:+1GB -t 1:ef00 -c 1:"EFI System Partition" /dev/disk/by-id/$did
sgdisk -n 2:0:+8GB -t 2:8200 -c 2:"Swap" /dev/disk/by-id/$did
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Main Data" /dev/disk/by-id/$did


mkswap /dev/disk/by-id/$did-part2
swapon /dev/disk/by-id/$did-part2

zpool create -f \
  -o ashift=12 \
  -o cachefile=/etc/zfs/zpool.cache \
  -o altroot=/mnt \
  -o autoexpand=on \
  -o autoreplace=on \
  rpool /dev/disk/by-id/$did-part3

zfs set mountpoint=legacy rpool
zfs set compression=lz4 rpool
zfs set recordsize=128K rpool
zfs set primarycache=all rpool
zfs set secondarycache=all rpool
zfs set acltype=posixacl rpool
zfs set xattr=sa rpool
zfs set atime=on rpool
zfs set relatime=on rpool

mount -t zfs rpool /mnt

zfs create \
  -o setuid=off \
  -o devices=off \
  -o sync=disabled \
  -o acltype=posixacl \
  -o xattr=sa \
  -o atime=on \
  -o relatime=on \
  -o primarycache=all \
  -o secondarycache=all \
  -o compression=lz4 \
  -o redundant_metadata=most \
  -o mountpoint=legacy \
  rpool/tmp

cp --parents /etc/zfs/zpool.cache /mnt

mkdir -p /mnt/tmp
mount -t zfs rpool/tmp /mnt/tmp
chmod 1777 /mnt/tmp

mkdir /mnt/boot
mkfs.fat -F 32 /dev/disk/by-id/$did-part1
mount -t vfat /dev/disk/by-id/$did-part1 /mnt/boot
```

### Installing Configuration

```sh
nix-env -i git
mkdir -p /mnt/etc
git clone --recursive https://github.com/Zachaccino/NixOS-Asus-UX533F.git /mnt/etc/nixos
nixos-install -I nixpkgs=/mnt/etc/nixos/nixpkgs --no-channel-copy --max-jobs $(nproc) --cores $(nproc)
# nixos-install will ask you to set the root password
```


### Reboot

```sh
shutdown now
# boot into your main disk not, remove the ISO from the CD
```

Remove installation ISO.

Once you've rebooted, you'll need to login as the root user via TTY1 (<kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>F1</kbd>).

Then you need to create your local user. Make sure to set the `$user` and `$desc`.

```sh
# change user and desc accordingly
user="user"
desc="User"
useradd \
  --create-home \
  --no-user-group \
  --gid=operators \
  --groups=wheel,users,networkmanager,docker,adbusers,plugdev \
  --comment="$desc" \
  "$user"
su - "$user" -c "true"
passwd "$user"
# copy your public key into .ssh/authorized_keys to be able to ssh in later
# we delete root password once we have the superuser
passwd --delete root
reboot
# after rebooting login normally
```

Remove the default nixos channel:

```
sudo nix-channel --remove nixos
```

## Updating

Go to nixpkgs-channels https://github.com/NixOS/nixpkgs-channels and find a recent release branch such as `nixos-19.03`.

Find the commit hash you want to utilise.

Go to the nixpkgs submodule and update it:

```sh
pushd nixpkgs
git fetch --all
git checkout <COMMITHASH>
popd
```

Then run `nixos-rebuild switch`. Adjust the `configuration.nix` if you meet problems.
