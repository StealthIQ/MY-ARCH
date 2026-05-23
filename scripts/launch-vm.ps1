# LEOS QEMU Development VM (Windows)
# Run from PowerShell: .\scripts\launch-vm.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$VmDir = Join-Path $ProjectDir "vm"
$Disk = Join-Path $VmDir "LEOS.qcow2"
$DiskSize = "60G"
$Ram = "4G"
$Cpus = 4
$ArchIso = Join-Path $VmDir "archlinux.iso"

# Create vm directory
New-Item -ItemType Directory -Force -Path $VmDir | Out-Null

# Check QEMU is installed
$qemu = Get-Command "qemu-system-x86_64" -ErrorAction SilentlyContinue
if (-not $qemu) {
    Write-Host "QEMU not found. Install from: https://www.qemu.org/download/#windows" -ForegroundColor Red
    Write-Host "Or: winget install SoftwareFreedomConservancy.QEMU" -ForegroundColor Yellow
    exit 1
}

# Download Arch ISO if not present
if (-not (Test-Path $ArchIso)) {
    Write-Host "Downloading Arch Linux ISO..." -ForegroundColor Cyan
    $mirror = "https://geo.mirror.pkgbuild.com/iso/latest"
    $page = Invoke-WebRequest -Uri "$mirror/" -UseBasicParsing
    $isoName = ($page.Links | Where-Object { $_.href -match "archlinux-\d{4}\.\d{2}\.\d{2}-x86_64\.iso$" } | Select-Object -First 1).href
    Invoke-WebRequest -Uri "$mirror/$isoName" -OutFile $ArchIso
    Write-Host "Downloaded: $isoName" -ForegroundColor Green
}

# Create disk image if not present
if (-not (Test-Path $Disk)) {
    Write-Host "Creating $DiskSize disk image..." -ForegroundColor Cyan
    & qemu-img create -f qcow2 $Disk $DiskSize
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Launching LEOS Dev VM" -ForegroundColor Green
Write-Host "   RAM: $Ram | CPUs: $Cpus | Disk: $DiskSize" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Install tips:" -ForegroundColor Yellow
Write-Host "  1. Boot the ISO, partition disk (fdisk /dev/vda)" -ForegroundColor Yellow
Write-Host "  2. mkfs.btrfs -f /dev/vda2" -ForegroundColor Yellow
Write-Host "  3. mount -o compress=zstd:3 /dev/vda2 /mnt" -ForegroundColor Yellow
Write-Host "  4. pacstrap /mnt base linux linux-firmware btrfs-progs" -ForegroundColor Yellow
Write-Host "  5. After install, run launch-vm-disk.ps1 to boot from disk" -ForegroundColor Yellow
Write-Host ""

# Launch with KVM if available (Windows with WHPX), otherwise without
$accel = "whpx"  # Windows Hypervisor Platform
# Fallback: $accel = "tcg" if WHPX not available

& qemu-system-x86_64 `
    -accel $accel `
    -m $Ram `
    -smp $Cpus `
    -drive "file=$Disk,format=qcow2,if=virtio" `
    -cdrom $ArchIso `
    -boot d `
    -nic "user,model=virtio-net-pci" `
    -display gtk `
    -vga virtio
