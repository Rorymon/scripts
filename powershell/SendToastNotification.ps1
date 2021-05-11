# Demo script to display a custom 'toast' notification

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

# User-populated variables
$WindowHeight = 140
$WindowWidth = 480
$Title = "Performance Review Update"
$Text = "Performance review dates have changed. Click here to read the new key dates."
$Timeout = 10
$ImageHeight = 100
$ImageWidth = 100

# Set screen working area, bounds and start and finish location of the window 'top' property (for animation)
$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$TopStart = $workingArea.Bottom
$TopFinish = $workingArea.Bottom - ($WindowHeight + 10)
$CloseFinish = $Bounds.Bottom

# Code to create a base64 string from an image file
<#
$File = "\\slhnaz.org\ctx\Software\Tools\Customizations\Toast\HHToastLogo.PNG"
$Image = [System.Drawing.Image]::FromFile($File)
$MemoryStream = New-Object System.IO.MemoryStream
$Image.Save($MemoryStream, $Image.RawFormat)
[System.Byte[]]$Bytes = $MemoryStream.ToArray()
$Base64 = [System.Convert]::ToBase64String($Bytes)
$Image.Dispose()
$MemoryStream.Dispose()
#>

# Create the custom logo from Base64 string
$Base64 = "<LongBaseString>"
$CustomImage = New-Object System.Windows.Media.Imaging.BitmapImage
$CustomImage.BeginInit()
$CustomImage.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64)
$CustomImage.EndInit()

# Calculate element dimensions
$MainStackWidth = $WindowWidth - 10
$SecondStackWidth = $WindowWidth - $ImageWidth -10
$TextBoxWidth = $SecondStackWidth - 30

# Define the notification UI in Xaml
[XML]$Xaml = "
<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
    Title='Druva Notification' Width='$WindowWidth' Height='$WindowHeight'
    WindowStyle='None' AllowsTransparency='True' Background='Transparent' Topmost='True' Opacity='0.9'>
    <Window.Resources>
        <Storyboard x:Name='ClosingAnimation' x:Key='ClosingAnimation' >
            <DoubleAnimation Duration='0:0:.5' Storyboard.TargetProperty='Top' From='$TopFinish' To='$CloseFinish' AccelerationRatio='.1'/>
        </Storyboard>
    </Window.Resources>
    <Window.Triggers>
        <EventTrigger RoutedEvent='Window.Loaded'>
            <BeginStoryboard>
                <Storyboard >
                    <DoubleAnimation Duration='0:0:.5' Storyboard.TargetProperty='Top' From='$TopStart' To='$TopFinish' AccelerationRatio='.1'/>
                </Storyboard>
            </BeginStoryboard>
        </EventTrigger>
    </Window.Triggers>
    <Grid>
    <Border BorderThickness='0' Background='#333333'>
      <StackPanel Margin='20,10,20,10' Orientation='Horizontal' Width='$MainStackWidth'>
        <Image x:Name='Logo' Width='$ImageWidth' Height='$ImageHeight'/>
        <StackPanel Width='$SecondStackWidth'>
            <TextBox Margin='5' MaxWidth='$TextBoxWidth' Background='#333333' BorderThickness='0' IsReadOnly='True' Foreground='White' FontSize='20' Text='$Title' FontWeight='Bold' HorizontalContentAlignment='Center' Width='Auto' HorizontalAlignment='Stretch' IsHitTestVisible='False'/>
            <TextBox Margin='5' MaxWidth='$TextBoxWidth' Background='#333333' BorderThickness='0' IsReadOnly='True' Foreground='LightGray' FontSize='16' Text='$Text' HorizontalContentAlignment='Left' TextWrapping='Wrap' IsHitTestVisible='False'/>
        </StackPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"

# Create a global hash table to add dispatcher to
$Global:UI = @{}

# Create the window
$Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))

# Set the image
$Logo = $Window.FindName('Logo')
$Logo.Source = $CustomImage

# Add the closing animation to the global variable
$UI.ClosingAnimation = $Window.FindName('ClosingAnimation')

# Window loaded
$Window.Add_Loaded({

    # Activate
    $This.Activate()
    
    # Play a sound
    $SoundFile = "$env:SystemDrive\Windows\Media\Windows Notify.wav"
    $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
    $SoundPlayer.Add_LoadCompleted({
        $This.Play()
        $This.Dispose()
    })
    $SoundPlayer.LoadAsync()

    # Set the location of the left property
    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $this.Left = $workingarea.Width - ($this.ActualWidth + 10)

    # Create a dispatcher timer to begin notification closure after x seconds
    $UI.DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
    $UI.DispatcherTimer.Interval = [TimeSpan]::FromSeconds($Timeout)
    $UI.DispatcherTimer.Add_Tick({
        $UI.ClosingAnimation.Begin($Window)
    })
    $UI.DispatcherTimer.Start()

})

# Window closing
$Window.Add_Closing({
    # Stop the dispatcher timer
    $UI.DispatcherTimer.Stop()
})

# Closing animation is completed
$UI.ClosingAnimation.Add_Completed({
    $Window.Close()
})

# Window Mouse enter
$Window.Add_MouseEnter({
    # Change cursor to a hand
    $This.Cursor = 'Hand'
})

# Window mouse up (simulate click)
$Window.Add_MouseUp({
    # Open a web page, stop the dispatcher timer and close the notification
    Start-Process "https://pulsenews.honorhealth.com/performance-reviews-update"
    $UI.DispatcherTimer.Stop()
    $This.Close()
})

# Display the notification
$null = $window.Dispatcher.InvokeAsync{$window.ShowDialog()}.Wait()
