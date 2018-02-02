 function main {
 
	$user = <User>
	$domain = <domain>
	$Group = "Direct Access Users"
	$computers = @(<hostnames>) 
 
	foreach ($Computer in $Computers) {
		write-host $computer -foregroundcolor green
		Add-LocalUser -Computer $Computer -group $group -userdomain $domain -username $user
	}
}
 
function Add-LocalUser{
     Param(
        $computer=$env:computername,
        $group="Direct Access Users",
        $userdomain=$env:userdomain,
        $username=$env:username
    )
        ([ADSI]"WinNT://$computer/$Group,group").psbase.Invoke("Add",([ADSI]"WinNT://$domain/$user").path)
}
 
main 
