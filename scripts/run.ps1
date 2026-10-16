param(
    [string]$DiskImage = 'iso/akiba.img',
    [string]$Qemu = 'qemu-system-x86_64.exe',
    [string]$FirmwareCode = $env:AKIBA_UEFI_CODE,
    [string]$FirmwareVars = $env:AKIBA_UEFI_VARS,
    [ValidateRange(0, 65535)][int]$QmpPort = 0,
    [string]$SerialLog = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not [System.IO.Path]::IsPathRooted($DiskImage)) {
    $DiskImage = Join-Path $root $DiskImage
}
if (-not (Test-Path -LiteralPath $DiskImage -PathType Leaf)) {
    throw "Boot image not found: $DiskImage. Run make first."
}
$DiskImage = (Resolve-Path -LiteralPath $DiskImage).Path
$qemuPath = (Get-Command $Qemu -ErrorAction Stop).Source

if ([bool]$FirmwareCode -ne [bool]$FirmwareVars) {
    throw 'Specify both FirmwareCode and FirmwareVars when overriding the UEFI firmware.'
}
if (-not $FirmwareCode) {
    $binaryDirectory = Split-Path $qemuPath -Parent
    $directories = @(
        (Join-Path $binaryDirectory 'share'),
        (Join-Path $binaryDirectory '../share/qemu'),
        (Join-Path $env:USERPROFILE 'scoop/apps/qemu/current/share')
    )
    foreach ($directory in $directories) {
        $code = Join-Path $directory 'edk2-x86_64-code.fd'
        $vars = Join-Path $directory 'edk2-i386-vars.fd'
        if ((Test-Path -LiteralPath $code -PathType Leaf) -and (Test-Path -LiteralPath $vars -PathType Leaf)) {
            $FirmwareCode = $code
            $FirmwareVars = $vars
            break
        }
    }
}
if (-not $FirmwareCode -or -not $FirmwareVars) {
    throw 'UEFI firmware not found. Set AKIBA_UEFI_CODE and AKIBA_UEFI_VARS to a matching firmware pair.'
}
$FirmwareCode = (Resolve-Path -LiteralPath $FirmwareCode).Path
$FirmwareVars = (Resolve-Path -LiteralPath $FirmwareVars).Path
$variables = Join-Path ([System.IO.Path]::GetTempPath()) ('akiba-vars-' + [guid]::NewGuid().ToString() + '.fd')
$serial = 'stdio'
if ($SerialLog) {
    $serial = 'file:' + $SerialLog
}
$arguments = @(
    '-M', 'q35', '-accel', 'tcg', '-m', '2048M',
    '-drive', ('if=pflash,format=raw,readonly=on,file=' + $FirmwareCode),
    '-drive', ('if=pflash,format=raw,file=' + $variables),
    '-drive', ('file=' + $DiskImage + ',format=raw'),
    '-snapshot', '-serial', $serial, '-no-reboot', '-name', 'Akiba'
)
if ($QmpPort -gt 0) {
    $arguments += @('-qmp', "tcp:127.0.0.1:$QmpPort,server=on,wait=off")
}

$exitCode = 1
try {
    Copy-Item -LiteralPath $FirmwareVars -Destination $variables
    & $qemuPath @arguments
    $exitCode = $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $variables) {
        Remove-Item -LiteralPath $variables -Force -Confirm:$false
    }
}
exit $exitCode
