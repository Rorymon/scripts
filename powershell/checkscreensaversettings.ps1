
$screensaver =  Get-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name "SCRNSAVE.EXE" -erroraction 'silentlycontinue'


If ($screensaver -ne $null){
$screensactive = Get-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name "ScreenSaveActive"
$screentimeout = Get-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name "ScreenSaveTimeOut"
$screensecure = Get-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name "ScreenSaverIsSecure"

$screensaver | out-string
$screensaver = $screensaver.'SCRNSAVE.EXE'

$screentimeout | out-string 
$screentimeout = $screentimeout.ScreenSaveTimeOut

$screensecure = $screensecure.ScreenSaverIsSecure

If ($screensecure -eq 0){
write-host "When the screen saver is stopped, Windows may not prompt for logon."
}
else
{
write-host "Screen Saver Set to return to logon screen when interaction happens."
}

write-host "Screen Saver Set to $screensaver"
write-host "Screen Saver Set to Timeout $screentimeout seconds"

} 
else
{
write-host "Screen Saver is not set"
}
