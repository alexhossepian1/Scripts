#User State Migration Script
#------------------------------------------------------------------------------------------------------------------------------------#

# Ensure admin elevation 
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting elevated...'
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath")
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit
}

Write-Host "
  .------------------------------------------------------------------------.
  |                    User State Migration Script                         |
  |                                                                        |
  |                                                                        |
  | Select a option bellow:                                                |
  | [1] Scan User                                                          |
  | [2] Load User                                                          |
  | [3] Delete User File                                                   |
  | [4] Exit                                                               |
  .------------------------------------------------------------------------.
" -ForegroundColor Cyan
# If you want a different share path or drive letter, change the variables below.
$Drive_Letter = 'X'
$Share_Path = "" #your share path here, example: \\server\share
$amd64 = "${Drive_Letter}:\amd64"
$Option = Read-Host "Select an Option:" 

switch ($Option)
{
  1 { 
      # Our mount drive  
      Write-Host "Mapping ${Drive_Letter}: to ${Share_Path}..."
      Get-PSDrive -Name $Drive_Letter -ErrorAction SilentlyContinue 
      net use ${Drive_Letter}: /delete 
      Start-Sleep -Seconds 3
      net use ${Drive_Letter}: $Share_Path /persistent:yes


    if (-not (Test-Path -LiteralPath "${Drive_Letter}:\")) {
    throw "Drive ${Drive_Letter}: is not accessible after mapping. Root: ${Share_Path}"
    }
      # Get User ID and create folder for user
      $User_ID = Read-Host "Enter User ID"
      
      Write-Host "Creating Migration Folder for $User_ID..."

      # Create folder for user
      $User_Folder = "${Drive_Letter}:\\${User_ID}"
      if (-not (Test-Path -LiteralPath $User_Folder)) {
        Write-Host "Creating user folder: $User_Folder"
        New-Item -Path $User_Folder -ItemType Directory -Force | Out-Null
        }   
      if (!(Test-Path -Path $User_Folder)) {
        Write-Host "ERROR: Failed to create folder for $User_ID." -ForegroundColor Red
        exit
      }


      Write-host "Created folder for $User_ID."
      #Arguments
      $args = @(
          "${User_Folder}",
          "/ui:YOURDOMAIN\${User_ID}", #Change YOURDOMAIN to your domain name, if not in a domain environment you can use the local computer name or just the username without a prefix
          "/ue:*\*",
          "/i:MigUser.xml",
          "/i:MigDocs.xml",
          "/v:13",
          "/o",
          "/c"
      )
      
      Write-Host "Scanstate starting..."
      Set-Location "${amd64}"
      .\scanstate.exe @args

      # AutomaticDestinations copy/grab
      Write-Host "Copying Automatic Destination Files..."
      $src = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations'
      Copy-Item -LiteralPath $src -Destination $User_Folder -Recurse -Force -ErrorAction Stop
      
      Start-Sleep -Seconds 1.5
      Write-Host "Done."
      
    }
    
  2 {      
      # Our mount drive     
      Write-Host "Mapping ${Drive_Letter}: to ${Share_Path}..."
      Get-PSDrive -Name $Drive_Letter -ErrorAction SilentlyContinue 
      net use ${Drive_Letter}: /delete 
      Start-Sleep -Seconds 3
      net use ${Drive_Letter}: $Share_Path /persistent:yes

      if (-not (Test-Path -LiteralPath "${Drive_Letter}:\")) {
      throw "Drive ${Drive_Letter}: is not accessible after mapping. Root: ${Share_Path}"
      }


      # Get User ID
      $User_ID = Read-Host "Enter User ID"
      $User_Folder = "${Drive_Letter}:\\${User_ID}"
      
      if (!(Test-Path -Path $User_Folder)) {
          Write-Host "ERROR: Folder for $User_ID not found." -ForegroundColor Red
          Start-Sleep 4
          exit
      }
      Write-host "Found folder for $User_ID."
      #Arguments
      $args = @(
          "${User_Folder}",
          "/lac",
          "/lae",
          "/i:MigUser.xml",
          "/i:MigDocs.xml",
          "/v:13",
          "/c"
          
      )
      #Starting loadstate
      Write-Host "Loadstate starting"
      Set-Location "$amd64"
      .\loadstate.exe @args

      #Pinned paths
      Write-Host "Replacing Automatic Destination Files..."
      $dst = "C:\\Users\${User_ID}\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
      $stored = Join-Path $User_Folder 'AutomaticDestinations'
      $dstParent = Split-Path -Parent $dst
      New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
      if (Test-Path -LiteralPath $dst) {
          Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction Stop
      }

      Copy-Item -LiteralPath $stored -Destination $dstParent -Recurse -Force -ErrorAction Stop
      

      Start-Sleep -Seconds 3
      Write-Host "Done."
    }
  3 {
      # Our mount drive     
      Write-Host "Mapping ${Drive_Letter}: to ${Share_Path}..."
      Get-PSDrive -Name $Drive_Letter -ErrorAction SilentlyContinue 
      net use ${Drive_Letter}: /delete 
      Start-Sleep -Seconds 3
      net use ${Drive_Letter}: $Share_Path /persistent:yes

      if (-not (Test-Path -LiteralPath "${Drive_Letter}:\")) {
      throw "Drive ${Drive_Letter}: is not accessible after mapping. Root: ${Share_Path}"
      }

      # Get User ID
      $User_ID = Read-Host "Enter User ID"
      $User_Folder = "${Drive_Letter}:\\${User_ID}"
      
      if (!(Test-Path -Path $User_Folder)) {
          Write-Host "ERROR: Folder for $User_ID not found." -ForegroundColor Red
          Start-Sleep 4
          exit
      }
      Write-host "Found folder for $User_ID."
    
      #Remove user folder to save drive space
      Write-Host "Removing $User_Folder"
      Remove-Item -Path $User_Folder -Recurse -Force
      if ((Test-Path -Path $User_Folder)) {
      Write-Host "ERROR: Failed to remove folder for $User_ID" -ForegroundColor Red -SilentlyContinue
      }
      else {
        Write-Host "Succesfully removed $User_ID" -ForegroundColor Green
      }

    }
  
  default { 
        Write-Host 'Goodbye'
        Start-Sleep 4
    }
}
