# Boot LEOS from disk (after Arch installation)
# Run: .\scripts\launch-vm-disk.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$VmDir = Join-Path $ProjectDir "vm"
$Disk = Join-Path $VmDir "LEOS.qcow2"

# Share the project folder into the VM via 9p
# Inside VM: mount -t 9p -o trans=virtio host_share /mnt/project

& qemu-system-x86_64 `
    -accel whpx `
    -m 4G `
    -smp 4 `
    -drive "file=$Disk,format=qcow2,if=virtio" `
    -boot c `
    -nic "user,model=virtio-net-pci,hostfwd=tcp::2222-:22" `
    -display gtk `
    -vga virtio `
    -virtfs "local,path=$ProjectDir,mount_tag=host_share,security_model=mapped-xattr"
