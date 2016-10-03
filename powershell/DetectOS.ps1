<#
.SYNOPSIS
    .
.DESCRIPTION
    This script takes a computer name and Outputs the Operating System being run ####
    Created by Rory Monaghan. 
.PARAMETER computer
    An computer hostname
#>



Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$computer
)

Get-WMIObject Win32_OperatingSystem -ComputerName $computer |
select-object Description,
Caption,OSArchitecture,
ServicePackMajorVersion
