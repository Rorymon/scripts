 function main {
$file = "C:\HostnameList.xlsx"
$sheetName = "Sheet1"
$domain = "<Domain>"
$Group = "Direct Access Users"

 

　
$objExcel = New-Object -ComObject Excel.Application
$workbook = $objExcel.Workbooks.Open($file)
$sheet = $workbook.Worksheets.Item($sheetName)
$objExcel.Visible=$false

$rowMax = ($sheet.UsedRange.Rows).count

$rowWName,$colWName = 1,1
$rowUName,$colUName = 1,2

for ($i=1; $i -le $rowMax-1; $i++)
{
$Wname = $sheet.Cells.Item($rowWName+$i,$colWName).text
$Uname = $sheet.Cells.Item($rowUName+$i,$colUName).text
Write-host("Workstation:$Wname is assigned to $Uname")
$user = $Uname
Add-LocalUser -Computer $Wname -group $group -userdomain $domain -username $Uname
}

$objExcel.quit()
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
