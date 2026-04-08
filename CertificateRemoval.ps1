#Checks for admin privileges and restarts elevated if not admin
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting elevated...'
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath")
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit
}
# Our Variable for the certificate store path
$storePath = 'Cert:\LocalMachine\My'
$example1 = '' #Put the Issuer name of the certificate you want to remove here
$example2 = ''

#Start of the removal process
try {
    $cert = Get-ChildItem -Path $storePath -ErrorAction Stop |
        Where-Object {
            $_.Issuer -like "*$example1*" -or
            $_.Issuer -like "*$example2*"
        }

    if (-not $cert) {
        Write-Host "No certificates found with '$example1' or '$example2'."
        return
    }

    Write-Host "Found something to remove from $storePath ('$example1' or '$example2'):"
    $cert | Select-Object Subject, Thumbprint, NotAfter, Issuer | Format-Table -AutoSize
    $target = Join-Path $storePath $cert.Thumbprint

    Remove-Item -Path $target -Force -ErrorAction Stop
    Write-Host "Removed: $($cert.Thumbprint) (Subject='$($cert.Subject)')"
    Write-Host "Done"
}

catch {
    Write-Error "Failed"
}