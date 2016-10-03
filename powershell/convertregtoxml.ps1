<# Added by Michael Pietroforte #>
Param(
  [Parameter(Mandatory=$True)][string]$regPath,
  [Parameter(Mandatory=$True)][string]$xmlPath
  )

<# 
Orginal script by Malcolm McCaffery 
Syntax:  .\RegToXML.ps1 c:\path\input.reg c:\path\output.xml
Copy output.xml and Paste it in the edit part of Registery GPO 
More info at the http://chentiangemalc.wordpress.com/2014/07/02/importing-reg-files-into-group-policy-preferences/
#>

function Convert-RegEscapeCodes
{
Param(
    [Parameter(Position=1)][string]$regstring)
    return $regstring.Replace("\\","\").Replace('\"','"')
}

function Convert-Reg2Xml
{
Param(
  [Parameter(Mandatory=$True)][string]$regPath,
  [Parameter(Mandatory=$True)][string]$xmlPath
  )


  $clsidCollection = "{53B533F5-224C-47e3-B01B-CA3B3F3FF4BF}"
  $clsidRegistry =   "{9CD4B2F4-923D-47f5-A062-E897DD1DAD50}"

  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Indent=$True
  $settings.Encoding = [System.Text.Encoding]::UTF8

  $xml = [System.Xml.XmlWriter]::Create($xmlPath,$settings)
  $descr = "Imported Reg File"
  $action = "U"

  $unicoder = New-Object System.Text.UnicodeEncoding

  $lastHive="";
  $lastKey="";
  write-host $regPath
  $sr=New-Object System.IO.StreamReader($regPath)

  $lastHive=""
  $lastKey=""

  $collectionCount=0

  while (!$sr.EndOfStream)
  {
  
    $line = $sr.ReadLine()
    if ($line.StartsWith("["))
    {
        $currentHive=$line.Substring(1,$line.IndexOf("\")-1)
        $currentKey=$line.Substring($line.IndexOf("\")+1,$line.Length-$line.IndexOf("\")-2)

        if ($lastHive -eq "")
        {
            $xml.WriteStartElement("Collection")
            $xml.WriteAttributeString("clsid",$clsidCollection)
            $xml.WriteAttributeString("name",$currentHive)
            $collectionCount++

            ForEach ($key in $currentKey.Split('\'))
            {
                $xml.WriteStartElement("Collection")
                $xml.WriteAttributeString("clsid",$clsidCollection)
                $xml.WriteAttributeString("name",$key)
                $collectionCount++
            }
        }
        else
        {
           # hives don't match - settings.xml doesn't support this!
            if ($currentHive -ne $lastHive)
            {
               # invalid - settings.xml only supports one HIVE type per file
               Throw "Reg file format is not supported by settings .XML. Please use only $currentHive or $lastHive per XML file"
               return
            }
            else
            {
                # going up a key
                if ($currentKey.StartsWith($lastKey + "\"))
                {
                    $newKey=$currentKey.Substring($lastKey.Length+1)
                    ForEach ($key in $newKey.Split('\'))
                    {
                        $xml.WriteStartElement("Collection")
                        $xml.WriteAttributeString("clsid",$clsidCollection)
                        $xml.WriteAttributeString("name",$key)
                        $collectionCount++
                    }
                }
                else
                {
                    # funky logic to handle change in key path
                    # maybe this logic even works :)
                    $currentKeySplit=$currentKey.Split('\')
                    $lastKeySplit=$lastKey.Split('\')

                    $match=$true

                    $i=-1

                    while ($match)
                    {
                        $i++
                        if ($i -ge $currentKeySplit.Length -or $i -ge $lastKeySplit.Length)
                        {
                            $match=$false
                        }
                        else
                        {
                            if ($currentKeySplit[$i] -ne $lastKeySplit[$i]) { $match=$false }
                        }
                    }

                    for ($x=$lastKeySplit.Length;$x -gt $i;$x--)
                    {
                        $xml.WriteEndElement()
                        $collectionCount--
                    }

                    for ($x=$i;$x -lt $currentKeySplit.Length;$x++)
                    {
                        $xml.WriteStartElement("Collection")
                        $xml.WriteAttributeString("clsid",$clsidCollection)
                        $xml.WriteAttributeString("name",$currentKeySplit[$x])
                        $collectionCount++
                    }
                    
                }
            }
        }
        
        $lastHive=$currentHive
        $lastKey=$currentKey
    }
    else
    {
        if ($line.Contains("="))
        {
            $regType=[Microsoft.Win32.RegistryValueKind]::Unknown

            # detect registry type 
            if ($line.StartsWith("@=") -or $line.Contains('"="')) { $regType=[Microsoft.Win32.RegistryValueKind]::String }
            if ($line.Contains("=hex:")) { $regType=[Microsoft.Win32.RegistryValueKind]::Binary }
            if ($line.Contains("=dword:")) { $regType=[Microsoft.Win32.RegistryValueKind]::DWord }
            if ($line.Contains("=hex(7):")) { $regType=[Microsoft.Win32.RegistryValueKind]::MultiString }
            if ($line.Contains("=hex(2):")) { $regType=[Microsoft.Win32.RegistryValueKind]::ExpandString }
            if ($line.Contains("=hex(b):")) { $regType=[Microsoft.Win32.RegistryValueKind]::QWord }

            switch ($regType)
            {
                # *** PROCESS REG_SZ
                ([Microsoft.Win32.RegistryValueKind]::String)
                {
                    $default="0"
                    if ($line.StartsWith("@="))
                    {
                        $valueName=""
                        $value=$line.Substring(3,$line.Length-4)
                        "Name = '$valueName' Value = '$value'"
                        $default="1"
                    }
                    else
                    {
                        $i = $line.IndexOf('"="')
                        $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                        $value=Convert-RegEscapeCodes $line.Substring($i+3,$line.Length-$i-4)
                       "Name = '$valueName' Value = '$value'"
                 
                    }

                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","7")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default",$default)
                    $xml.WriteattributeString("type","REG_SZ")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value)
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
         }

                # *** PROCESS REG_BINARY
                ([Microsoft.Win32.RegistryValueKind]::Binary)
                {
                    # read binary key to end
                    while ($line.EndsWith("\"))
                    {
                        $line=$line.Substring(0,$line.Length-1)+$sr.ReadLine().Trim()
                    }

                    $i = $line.IndexOf('"=hex:')
                    $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                    $value=$line.Substring($i+6).Replace(",","")
                    "Name = '$valueName' Value = '$value'"

                    # build XML
                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","17")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default","0")
                    $xml.WriteattributeString("type","REG_BINARY")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value)
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()

                }

                # *** PROCESS REG_DWORD
                ([Microsoft.Win32.RegistryValueKind]::DWord)
                {
                
                    $i = $line.IndexOf('"=dword:')
                    $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                    $value=$line.Substring($i+8).ToUpper()
                     "Name = '$valueName' Value = '$value'"

                    # build XML
                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","17")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default","0")
                    $xml.WriteattributeString("type","REG_DWORD")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value)
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
                }

                # *** PROCESS REG_QWORD
                ([Microsoft.Win32.RegistryValueKind]::QWord)
                {
                    $i = $line.IndexOf('"=hex(b):')
                    $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                    $tempValue=$line.Substring($i+9).Replace(",","").ToUpper()
                    $value=""

                    # unreverse QWORD for settings.xml format
                    for ($i = $tempValue.Length -2;$i -gt 0;$i-=2)
                    {
                        $value+=$tempValue.Substring($i,2)
                    }
                    
                     "Name = '$valueName' Value = '$value'"

                     # build XML
                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","17")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default","0")
                    $xml.WriteattributeString("type","REG_QWORD")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value)
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
                }

                # *** PROESS REG_MULTI_MZ
                ([Microsoft.Win32.RegistryValueKind]::MultiString)
                {
                    # read binary key to end
                    while ($line.EndsWith("\"))
                    {
                        $line=$line.Substring(0,$line.Length-1)+$sr.ReadLine().Trim()
                    }

                    # read hex codes
                    $i = $line.IndexOf('"=hex(7):')
                    $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                    $value=$line.Substring($i+9).Replace(",","")
                    # convert hex codes to binary array
                    $byteLength=$value.Length/2
                    $byte = New-Object Byte[] $byteLength
                    
                    $x=0
                    for ($i=0;$i -lt $value.Length;$i+=2)
                    {
                        $byte[$x]="0x" + $value.Substring($i,2)
                        $x++
                    }

                    # convert binary array to unicode string
                    $value=$unicoder.GetString($byte)

                    # retrieve multi values
                    $values=$value.Replace("`0`0","").Split("`0")
                    
                    "Name = '$valueName'"

                     # build XML
                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","7")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default","0")
                    $xml.WriteattributeString("type","REG_MULTI_SZ")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value.Replace("`0"," "))
                   
                    $x=1

                    $xml.WriteStartElement("Values")

                    ForEach ($value in $values)
                    {
                        $xml.WriteStartElement("Value")
                        $xml.WriteString($value)
                        "Value $x = '$value'"
                        $xml.WriteEndElement()
                    }
                    
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
                }

                ([Microsoft.Win32.RegistryValueKind]::ExpandString)
                {
                    # read binary key to end
                    while ($line.EndsWith("\"))
                    {
                        $line=$line.Substring(0,$line.Length-1)+$sr.ReadLine().Trim()
                    }

                    # read hex codes
                    $i = $line.IndexOf('"=hex(2):')
                    $valueName=Convert-RegEscapeCodes $line.Substring(1,$i-1)
                    $value=$line.Substring($i+9).Replace(",","")
                    # convert hex codes to binary array
                    $byteLength=$value.Length/2
                    $byte = New-Object Byte[] $byteLength
                    
                    $x=0
                    for ($i=0;$i -lt $value.Length;$i+=2)
                    {
                        $byte[$x]="0x" + $value.Substring($i,2)
                        $x++
                    }

                    # convert binary array to unicode string
                    $value=$unicoder.GetString($byte).Replace("`0","")
                    "Name = '$valueName' Value = '$value'"

                    $xml.WriteStartElement("Registry")
                    $xml.WriteAttributeString("clsid",$clsidRegistry)
                    $xml.WriteAttributeString("name",$valueName)
                    $xml.WriteAttributeString("descr",$descr)
                    $xml.WriteAttributeString("image","7")
                   
                    $xml.WriteStartElement("Properties")
                    $xml.WriteAttributeString("action",$action)
                    $xml.WriteAttributeString("hive",$currentHive)
                    $xml.WriteAttributeString("key",$currentKey)
                    $xml.WriteattributeString("name",$valueName)
                    $xml.WriteattributeString("default",$default)
                    $xml.WriteattributeString("type","REG_EXPAND_SZ")
                    $xml.WriteattributeString("displayDecimal","0")
                    $xml.WriteAttributeString("value",$value)
                    $xml.WriteEndElement()
                    $xml.WriteEndElement()
                }

            }

        }
        
    }

  }
  
  $sr.Close()
  while ($collectionCount -gt 0)
  {
        $xml.WriteEndElement()
        $collectionCount--
    }

    $xml.Close()
  
}
<# Replaced by Michael Pietroforte
Convert-Reg2Xml -regPath "C:\support\ReceiverCSTRegUpx64.reg" -xmlPath C:\support\Citrix.xml #>
Convert-Reg2Xml -regPath $regPath -xmlPath $xmlPath 
