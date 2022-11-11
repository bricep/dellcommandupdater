#

Function Get-OEM{
    $OEM=(Get-CimInstance Win32_Computersystem).manufacturer
    if ($OEM -imatch "Dell*")
    {
        Write-Output "Dude, it's a Dell! Continuing."
        Get-DCU
        }
    else {
        Write-Output "Not a Dell, exiting."
        Exit 0
    }
    }
    
    Function Get-DCU {
    $DownloadURL = "https://dl.dell.com/FOLDER05944445M/1/Dell-Command-Update_V104D_WIN_3.1.0_A00.EXE"
    $DownloadLocation = "C:\DCU"
    try {
        $TestDownloadLocation = Test-Path $DownloadLocation
        if (!$TestDownloadLocation) { new-item $DownloadLocation -ItemType Directory -force }
        $TestDownloadLocationZip = Test-Path "$DownloadLocation\DellCommandUpdate.exe"
        if (!$TestDownloadLocationZip) { 
            Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\DellCommandUpdate.exe"
            Start-Process -FilePath "$($DownloadLocation)\DellCommandUpdate.exe" -ArgumentList '/s' -Verbose -Wait
            set-service -name 'DellClientManagementService' -StartupType Manual
        }
     
    }
    catch {
        write-host "The download and extraction of DCUCli failed. Error: $($_.Exception.Message)"
        exit 1
    }

$results=@{}

#Updatetypes:bios,firmware,driver,application,
$Temp="C:\temp"
#Is DCU Running? Let's close it
Stop-Process -Name "DellCommandUpdate" -ErrorAction SilentlyContinue
start-process "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe" -ArgumentList "/scan -silent -report=$DownloadLocation -updatetype=firmware,driver,bios" -Wait
[ xml]$XMLReport = get-content "$DownloadLocation\DCUApplicableUpdates.xml"
#We now remove the item, because we don't need it anymore, and sometimes fails to overwrite
remove-item "$DownloadLocation\DCUApplicableUpdates.xml" -Force
$results=$XMLReport.updates.update
ForEach ($result in $results){
    Write-Output $($result.name + " | " + $result.version)
}
$BIOSUpdates        = ($XMLReport.updates.update | Where-Object {$_.type -eq "BIOS"}).name.Count
Write-Output $results.count

#Now Let's Install The Updates That Were Found
if ($results.count -eq 0)
{
    "No firmware updates found"
    Exit 0
}
if ($results.count -eq 1 -and $BIOSUpdates.count -eq 1){
    Write-Output "A BIOS update is available, no other firmware updates available"
    Exit 0
}
else {
    Write-Output "Installing Updates"
    $DownloadLocation = "$($Env:ProgramData)\DCU"
    start-process "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe" -ArgumentList "-updatetype=firmware,driver /applyUpdates -autoSuspendBitLocker=disable -reboot=disable" -Wait
    Write-Output "Finished installing updates."
    Exit 0
    }
}

Get-OEM