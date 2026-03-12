#Requires -Version 5.1
<#
.SYNOPSIS
    Animated ASCII art progress bar with silly statuses and FU Mode.

.PARAMETER Interval
    Seconds between progress ticks. Default: 1

.PARAMETER Period
    Total run duration in seconds. Default: 60

.PARAMETER ImageColor
    Starting accent color. Rotates each loop pass. Default: Cyan

.PARAMETER Loop
    Seconds for the wait screen between dance passes. 0 = single pass then exit. Default: 15

.PARAMETER FUMode
    Loads da-finger.txt and uses target-specific statuses.

.PARAMETER ExecTargetName
    Name of the target for FUMode status messages. Aliases: LeadTargetName, ManagerTargetName.
    Default: Peter

.PARAMETER RainbowMode
    Forces rainbow color cycling. Also has a 1-in-5 chance of auto-activating.

.EXAMPLE
    .\Show-ProgressBar.ps1
    .\Show-ProgressBar.ps1 -Period 30 -Loop 15
    .\Show-ProgressBar.ps1 -FUMode
    .\Show-ProgressBar.ps1 -FUMode -ExecTargetName "Dave"
    .\Show-ProgressBar.ps1 -RainbowMode

.NOTES
.VERSION 2.2.20250312
.CREATED_BY Tyler Jacobs
.CREATED_ON 2025-03-10
.UPDATED 2025-03-12

#>

[CmdletBinding()]
param
(
    [Parameter()]
    [int]    $Interval   = 1,

    [Parameter()]
    [int]    $Period     = 60,

    [Parameter()]
    [ValidateSet('Cyan','Green','Yellow','Magenta','White','Red')]
    [string] $ImageColor = 'Cyan',

    [Parameter()]
    [int]    $Loop       = 15,

    [Parameter()]
    [switch] $FUMode,

    [Parameter()]
    [Alias('LeadTargetName','ManagerTargetName')]
    [string] $ExecTargetName = 'Peter',

    [Parameter()]
    [switch] $RainbowMode
)

#region --- Configuration ---

$ImageFolder = Join-Path $PSScriptRoot "image-txt"
$FUImageFile = Join-Path $ImageFolder "da-finger.txt"

$FrameMs        = 80    # ms per main animation frame
$WipeFrameMs    = 40    # ms per line during slide-wipe flip
$ContentWidth   = 110   # max columns used by content; centered in window
$MinPanelWidth  = 60    # below this width the status panel is skipped

$FlipMinSec     = 15    # minimum seconds between image flips
$FlipMaxSec     = 35    # maximum seconds between image flips

$RainbowStepMin = 1     # minimum seconds between rainbow color steps
$RainbowStepMax = 5     # maximum seconds between rainbow color steps

$ColorCycle = [string[]]@('Cyan', 'Green', 'Yellow', 'Magenta', 'White', 'Red')

$StandardStatuses = @(
    "Compiling Nonsense",
    "Deleting System32",
    "Poking the Flux Capacitor",
    "Moving Some Bits Around",
    "Reticulating Splines",
    "Downloading More RAM",
    "Reversing the Polarity",
    "Feeding the Hamsters",
    "Untangling the Internet",
    "Calibrating the Coffee Sensor",
    "Rotating the Logs (Manually)",
    "Defragmenting the Cloud",
    "Syncing with the Mainframe",
    "Warming Up the Flux Drive",
    "Charging the Laser",
    "Asking Clippy for Help",
    "Patching Reality.exe",
    "Converting Oxygen to CO2",
    "Updating the Universe",
    "Rebooting Common Sense",
    "Negotiating with the Kernel",
    "Bribing the Scheduler",
    "Counting All the Zeroes",
    "Locating the Any Key"
)

$FUStatuses = @(
    # Name-specific statuses - {TARGET} is replaced at runtime
    "Messing with {TARGET}",
    "Annoying {TARGET}",
    "Waiting on {TARGET} to Get the Joke",
    "Processing {TARGET}'s Confusion",
    "Compiling {TARGET}'s Realization",
    "Hazing {TARGET} Back",
    "Giving {TARGET} a Taste of His Own Medicine",
    "Logging {TARGET}'s Reaction",
    "Documenting {TARGET}'s Face Right Now",
    "Syncing {TARGET}'s Brain to Current Events",
    "Submitting a Ticket About {TARGET}",
    "Cc-ing {TARGET}'s Manager",
    "Filing {TARGET} Under Unsolved Problems",
    "Running Diagnostics on {TARGET}",
    "Checking if {TARGET} Has Read the Error Message",
    "Waiting for {TARGET}'s Stack to Overflow",
    "Pinging {TARGET}: Request Timed Out",
    "Escalating {TARGET} to Tier 3 Support",
    "Patching {TARGET}.exe",
    "Reverting {TARGET}'s Last Commit",

    # Name-agnostic statuses
    "Blaming DNS",
    "It Was DNS the Whole Time",
    "Negotiating with the Garbage Collector",
    "Resolving a Dependency on Common Sense",
    "Waiting for the Heisenbug to Reproduce",
    "Turning It Off and Back On Again",
    "Reading the Stack Trace Upside Down",
    "rm -rf'ing the Problem",
    "Inverting the Boolean",
    "Achieving Nothing at Enterprise Scale"
)

$Spinner = [char[]]@('|', '/', '-', '\')

#endregion

#region --- Console Setup ---

function Invoke-ConsoleSetup
{
    # Maximizes the console window using SW_MAXIMIZE and disables QuickEdit mode.
    # SW_MAXIMIZE keeps the window genuinely windowed (not fullscreen), so Alt+Tab
    # and other hotkeys continue to work normally. QuickEdit is disabled to prevent
    # the window from freezing output when the user clicks it.
    # All calls are non-fatal if the terminal does not support them.
    try
    {
        $sig = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll", SetLastError = true)]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        if (-not ([System.Management.Automation.PSTypeName]'Win32.ConsoleHelper').Type)
        {
            Add-Type -MemberDefinition $sig `
                     -Name      'ConsoleHelper' `
                     -Namespace 'Win32' `
                     -ErrorAction Stop
        }

        $type = [Win32.ConsoleHelper]

        # SW_MAXIMIZE = 3 — windowed maximize, does not go fullscreen
        $hwnd = $type::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero)
        {
            $null = $type::ShowWindow($hwnd, 3)
            Start-Sleep -Milliseconds 200
        }

        # Disable QuickEdit so clicking the window does not freeze output.
        # STD_INPUT_HANDLE      = -10
        # ENABLE_QUICK_EDIT     = 0x0040  (bit to clear)
        # ENABLE_EXTENDED_FLAGS = 0x0080  (must be set when modifying QuickEdit)
        $stdIn = $type::GetStdHandle(-10)
        if ($stdIn -ne [IntPtr]::Zero)
        {
            [uint32]$mode = 0
            if ($type::GetConsoleMode($stdIn, [ref]$mode))
            {
                $mode = ($mode -band (-bnot 0x0040)) -bor 0x0080
                $null = $type::SetConsoleMode($stdIn, $mode)
            }
        }
    }
    catch
    {
        # Non-fatal - swallow silently
    }
}

#endregion

#region --- Layout Helpers ---

function Get-ContentLeft
{
    param ([int]$Width)
    $cw = $Host.UI.RawUI.WindowSize.Width
    return [Math]::Max(0, [int](($cw - $Width) / 2))
}

function Set-CursorPos
{
    param ([int]$X, [int]$Y)
    try
    {
        $win = $Host.UI.RawUI.WindowSize
        $buf = $Host.UI.RawUI.BufferSize
        $X   = [Math]::Max(0, [Math]::Min($X, $win.Width  - 1))
        $Y   = [Math]::Max(0, [Math]::Min($Y, $buf.Height - 1))
        $p   = $Host.UI.RawUI.CursorPosition
        $p.X = $X
        $p.Y = $Y
        $Host.UI.RawUI.CursorPosition = $p
    }
    catch
    {
        # Non-fatal - cursor position out of range during window resize
    }
}

function Write-ClearLine
{
    param ([int]$Row, [int]$ConsoleWidth)
    Set-CursorPos -X 0 -Y $Row
    Write-Host (' ' * ($ConsoleWidth - 1)) -NoNewline
    Set-CursorPos -X 0 -Y $Row
}

function Get-NextColorIndex
{
    param ([int]$CurrentIndex)
    return (($CurrentIndex + 1) % $ColorCycle.Count)
}

function Get-RandomStatusIndex
{
    param ([string[]]$Statuses, [int]$CurrentIndex)
    $next  = Get-Random -Maximum $Statuses.Count
    $tries = 0
    while ($next -eq $CurrentIndex -and $Statuses.Count -gt 1 -and $tries -lt 10)
    {
        $next = Get-Random -Maximum $Statuses.Count
        $tries++
    }
    return $next
}

#endregion

#region --- Image Helpers ---

function Get-ImageFiles
{
    if (-not (Test-Path $ImageFolder)) { return @() }

    return @(
        Get-ChildItem -Path $ImageFolder -Filter "*.txt" |
        Where-Object  { $_.Name -ne "da-finger.txt" } |
        Select-Object -ExpandProperty FullName
    )
}

function Get-AsciiImage
{
    param ([string]$FilePath)

    if ([string]::IsNullOrEmpty($FilePath) -or -not (Test-Path $FilePath))
    {
        return [string[]]@(
            "  .----------------------.",
            "  |   Image Not Found    |",
            "  '----------------------'"
        )
    }

    return [string[]]@(Get-Content -Path $FilePath)
}

function Get-MirroredLines
{
    param ([string[]]$Lines)

    $result = [string[]]::new($Lines.Count)

    for ($i = 0; $i -lt $Lines.Count; $i++)
    {
        $chars      = $Lines[$i].ToCharArray()
        [Array]::Reverse($chars)
        $result[$i] = [string]::new($chars)
    }

    return $result
}

#endregion

#region --- Render Functions ---

function Get-LineColor
{
    param
    (
        [int]    $LineIndex,
        [int]    $TotalLines,
        [double] $Progress,
        [string] $TargetColor
    )

    if ($TotalLines -le 1) { return $TargetColor }

    $lineFromBottom = $TotalLines - 1 - $LineIndex
    $lineFraction   = $lineFromBottom / [double]($TotalLines - 1)

    if ($lineFraction -gt $Progress)          { return 'DarkGray' }
    if (($Progress - $lineFraction) -lt 0.12) { return 'Gray'     }

    return $TargetColor
}

function Write-ImageFrame
{
    param
    (
        [string[]] $Lines,
        [double]   $Progress,
        [string]   $TargetColor,
        [int]      $HorizontalOffset,
        [int]      $TopRow
    )

    $cw        = $Host.UI.RawUI.WindowSize.Width
    $maxLen    = ($Lines | Measure-Object -Property Length -Maximum).Maximum
    $dispWidth = [Math]::Min($maxLen, $ContentWidth)
    $baseLeft  = [Math]::Max(0, [int](($cw - $dispWidth) / 2))

    for ($i = 0; $i -lt $Lines.Count; $i++)
    {
        $color    = Get-LineColor -LineIndex $i -TotalLines $Lines.Count `
                                  -Progress $Progress -TargetColor $TargetColor
        $leftPad  = [Math]::Max(0, $baseLeft + $HorizontalOffset)
        $line     = $Lines[$i]
        $maxChars = [Math]::Max(0, $cw - $leftPad - 1)
        if ($line.Length -gt $maxChars) { $line = $line.Substring(0, $maxChars) }

        Write-ClearLine -Row ($TopRow + $i) -ConsoleWidth $cw
        Set-CursorPos   -X $leftPad -Y ($TopRow + $i)
        Write-Host $line -ForegroundColor $color -NoNewline
    }
}

function Invoke-SlideWipe
{
    # Venetian-blind wipe: each line flips top-to-bottom, flashes Gray,
    # then settles into the correct progress color.
    param
    (
        [string[]] $ToLines,
        [double]   $Progress,
        [string]   $TargetColor,
        [int]      $HorizontalOffset,
        [int]      $TopRow
    )

    $cw        = $Host.UI.RawUI.WindowSize.Width
    $maxLen    = ($ToLines | Measure-Object -Property Length -Maximum).Maximum
    $dispWidth = [Math]::Min($maxLen, $ContentWidth)
    $baseLeft  = [Math]::Max(0, [int](($cw - $dispWidth) / 2))

    for ($i = 0; $i -lt $ToLines.Count; $i++)
    {
        $leftPad  = [Math]::Max(0, $baseLeft + $HorizontalOffset)
        $line     = $ToLines[$i]
        $maxChars = [Math]::Max(0, $cw - $leftPad - 1)
        if ($line.Length -gt $maxChars) { $line = $line.Substring(0, $maxChars) }

        # Flash gray for one wipe frame
        Write-ClearLine -Row ($TopRow + $i) -ConsoleWidth $cw
        Set-CursorPos   -X $leftPad -Y ($TopRow + $i)
        Write-Host $line -ForegroundColor Gray -NoNewline
        Start-Sleep -Milliseconds $WipeFrameMs

        # Settle into progress-appropriate color
        $color = Get-LineColor -LineIndex $i -TotalLines $ToLines.Count `
                               -Progress $Progress -TargetColor $TargetColor
        Write-ClearLine -Row ($TopRow + $i) -ConsoleWidth $cw
        Set-CursorPos   -X $leftPad -Y ($TopRow + $i)
        Write-Host $line -ForegroundColor $color -NoNewline
    }
}

function Write-StatusPanel
{
    param
    (
        [int]    $TopRow,
        [int]    $PanelWidth,
        [double] $Progress,
        [string] $StatusText,
        [int]    $SpinnerFrame,
        [int]    $ElapsedSec,
        [int]    $TotalSec,
        [string] $AccentColor
    )

    $TL = [char]0x2554; $TR = [char]0x2557
    $BL = [char]0x255A; $BR = [char]0x255D
    $H  = [char]0x2550; $V  = [char]0x2551
    $LT = [char]0x2560; $RT = [char]0x2563
    $BF = [char]0x2588; $EF = [char]0x2591

    $cw    = $Host.UI.RawUI.WindowSize.Width
    $left  = Get-ContentLeft -Width $PanelWidth
    $inner = $PanelWidth - 2

    # Status line
    $spin      = $Spinner[$SpinnerFrame % $Spinner.Count]
    $maxStatus = [Math]::Max(0, $inner - 6)
    if ($StatusText.Length -gt $maxStatus)
    {
        $StatusText = $StatusText.Substring(0, $maxStatus - 1) + [char]0x2026
    }
    $statusLine = (" $spin  $StatusText ").PadRight($inner)

    # Bar math
    $pctStr    = [string]::Format("{0,4:P0}", $Progress)
    $timeStr   = "${ElapsedSec}s/${TotalSec}s"
    $rightSide = "  $pctStr  $timeStr  "
    $barUsable = [Math]::Max(2, $inner - $rightSide.Length - 1)
    $filled    = [int]($barUsable * $Progress)
    $empty     = $barUsable - $filled

    # Row 0: ╔══╗
    Write-ClearLine -Row ($TopRow + 0) -ConsoleWidth $cw
    Set-CursorPos   -X $left -Y ($TopRow + 0)
    Write-Host ($TL.ToString() + ($H.ToString() * $inner) + $TR.ToString()) `
        -ForegroundColor $AccentColor -NoNewline

    # Row 1: ║ spinner  status text ║
    Write-ClearLine -Row ($TopRow + 1) -ConsoleWidth $cw
    Set-CursorPos   -X $left -Y ($TopRow + 1)
    Write-Host $V.ToString() -ForegroundColor $AccentColor -NoNewline
    Write-Host $statusLine   -ForegroundColor Yellow       -NoNewline
    Write-Host $V.ToString() -ForegroundColor $AccentColor -NoNewline

    # Row 2: ╠══╣
    Write-ClearLine -Row ($TopRow + 2) -ConsoleWidth $cw
    Set-CursorPos   -X $left -Y ($TopRow + 2)
    Write-Host ($LT.ToString() + ($H.ToString() * $inner) + $RT.ToString()) `
        -ForegroundColor $AccentColor -NoNewline

    # Row 3: ║ ████░░ 47%  12s/60s ║
    Write-ClearLine -Row ($TopRow + 3) -ConsoleWidth $cw
    Set-CursorPos   -X $left -Y ($TopRow + 3)
    Write-Host $V.ToString()              -ForegroundColor $AccentColor -NoNewline
    Write-Host " "                        -NoNewline
    Write-Host ($BF.ToString() * $filled) -ForegroundColor $AccentColor -NoNewline
    Write-Host ($EF.ToString() * $empty)  -ForegroundColor DarkGray     -NoNewline
    Write-Host $rightSide                 -ForegroundColor DarkGray     -NoNewline
    Write-Host $V.ToString()              -ForegroundColor $AccentColor -NoNewline

    # Row 4: ╚══╝
    Write-ClearLine -Row ($TopRow + 4) -ConsoleWidth $cw
    Set-CursorPos   -X $left -Y ($TopRow + 4)
    Write-Host ($BL.ToString() + ($H.ToString() * $inner) + $BR.ToString()) `
        -ForegroundColor $AccentColor -NoNewline
}

#endregion

#region --- Phase: Dancing Image ---

function Invoke-DancePhase
{
    # Displays the ASCII image with a status bar for $RunPeriod seconds.
    param
    (
        [string[]] $ImageLines,
        [string[]] $Statuses,
        [string]   $AccentColor,
        [int]      $RunPeriod,
        [bool]     $IsRainbow,
        [bool]     $AllowFlip
    )

    $ImageLines = [string[]]@($ImageLines)
    $Statuses   = [string[]]@($Statuses)

    $TopPad      = 2
    $cw          = $Host.UI.RawUI.WindowSize.Width
    $panelWidth  = [Math]::Min($ContentWidth, [Math]::Max($MinPanelWidth, $cw - 2))
    $panelTopRow = $TopPad + $ImageLines.Count + 1
    $showPanel   = ($cw -ge $MinPanelWidth)

    # Sine-wave dance
    $dancePhase      = (Get-Random -Minimum 0 -Maximum 628) / 100.0
    $danceAmplitude  = 16
    $speedOptions    = @(0.05, 0.07, 0.09, 0.11, 0.14)
    $danceSpeed      = $speedOptions[(Get-Random -Maximum $speedOptions.Count)]
    $nextSpeedChange = Get-Random -Minimum 25 -Maximum 80
    $frameCount      = 0

    # Status
    $statusIndex   = Get-Random -Maximum $Statuses.Count
    $statusChanged = [datetime]::Now

    # Rainbow
    $rainbowIndex   = [Array]::IndexOf($ColorCycle, $AccentColor)
    if ($rainbowIndex -lt 0) { $rainbowIndex = 0 }
    $rainbowChanged  = [datetime]::Now
    $nextRainbowSec  = Get-Random -Minimum $RainbowStepMin -Maximum ($RainbowStepMax + 1)
    $activeColor     = $AccentColor

    # Flip
    $mirroredLines = [string[]]@(Get-MirroredLines -Lines $ImageLines)
    $currentLines  = $ImageLines
    $isFlipped     = $false
    $nextFlipSec   = Get-Random -Minimum $FlipMinSec -Maximum $FlipMaxSec

    $spinnerFrame = 0
    $startTime    = [datetime]::Now
    $elapsed      = 0.0

    [Console]::CursorVisible = $false
    Clear-Host

    try
    {
        while ($elapsed -lt $RunPeriod)
        {
            $now      = [datetime]::Now
            $elapsed  = ($now - $startTime).TotalSeconds
            $progress = [Math]::Min(1.0, $elapsed / $RunPeriod)

            if ($IsRainbow -and (($now - $rainbowChanged).TotalSeconds -ge $nextRainbowSec))
            {
                $rainbowIndex   = Get-NextColorIndex -CurrentIndex $rainbowIndex
                $activeColor    = $ColorCycle[$rainbowIndex]
                $rainbowChanged = $now
                $nextRainbowSec = Get-Random -Minimum $RainbowStepMin -Maximum ($RainbowStepMax + 1)
            }

            if (($now - $statusChanged).TotalSeconds -ge 3)
            {
                $statusIndex   = Get-RandomStatusIndex -Statuses $Statuses -CurrentIndex $statusIndex
                $statusChanged = $now
            }

            if ($AllowFlip -and ($elapsed -ge $nextFlipSec))
            {
                $targetLines = if ($isFlipped) { $ImageLines } else { $mirroredLines }

                Invoke-SlideWipe `
                    -ToLines          $targetLines `
                    -Progress         $progress `
                    -TargetColor      $activeColor `
                    -HorizontalOffset 0 `
                    -TopRow           $TopPad

                $isFlipped    = -not $isFlipped
                $currentLines = $targetLines
                $nextFlipSec  = $elapsed + (Get-Random -Minimum $FlipMinSec -Maximum $FlipMaxSec)
            }

            $frameCount++
            $dancePhase  += $danceSpeed
            $danceOffset  = [int]([Math]::Sin($dancePhase) * $danceAmplitude)

            if ($frameCount -ge $nextSpeedChange)
            {
                $danceSpeed      = $speedOptions[(Get-Random -Maximum $speedOptions.Count)]
                $nextSpeedChange = Get-Random -Minimum 25 -Maximum 80
                $frameCount      = 0
            }

            Write-ImageFrame `
                -Lines            $currentLines `
                -Progress         $progress `
                -TargetColor      $activeColor `
                -HorizontalOffset $danceOffset `
                -TopRow           $TopPad

            if ($showPanel)
            {
                Write-StatusPanel `
                    -TopRow       $panelTopRow `
                    -PanelWidth   $panelWidth `
                    -Progress     $progress `
                    -StatusText   $Statuses[$statusIndex] `
                    -SpinnerFrame $spinnerFrame `
                    -ElapsedSec   ([int]$elapsed) `
                    -TotalSec     $RunPeriod `
                    -AccentColor  $activeColor
            }

            $spinnerFrame++
            Start-Sleep -Milliseconds $FrameMs
        }

        # Final frame at 100%
        Write-ImageFrame `
            -Lines            $currentLines `
            -Progress         1.0 `
            -TargetColor      $activeColor `
            -HorizontalOffset 0 `
            -TopRow           $TopPad

        if ($showPanel)
        {
            Write-StatusPanel `
                -TopRow       $panelTopRow `
                -PanelWidth   $panelWidth `
                -Progress     1.0 `
                -StatusText   "Done." `
                -SpinnerFrame 0 `
                -ElapsedSec   $RunPeriod `
                -TotalSec     $RunPeriod `
                -AccentColor  $activeColor
        }
    }
    finally
    {
        [Console]::CursorVisible = $true
    }
}

#endregion

#region --- Phase: Wait Screen ---

function Invoke-WaitPhase
{
    # No image. Displays a centered header and a status bar counting down $WaitSec.
    # Header: "Waiting Xs to check the progress of the progress bar"
    # Panel:  rotating random status messages with a countdown bar.
    param
    (
        [string[]] $Statuses,
        [string]   $AccentColor,
        [int]      $WaitSec,
        [bool]     $IsRainbow
    )

    $Statuses = [string[]]@($Statuses)

    $cw          = $Host.UI.RawUI.WindowSize.Width
    $panelWidth  = [Math]::Min($ContentWidth, [Math]::Max($MinPanelWidth, $cw - 2))
    $headerRow   = 2
    $panelTopRow = $headerRow + 2

    $statusIndex   = Get-Random -Maximum $Statuses.Count
    $statusChanged = [datetime]::Now

    $rainbowIndex   = [Array]::IndexOf($ColorCycle, $AccentColor)
    if ($rainbowIndex -lt 0) { $rainbowIndex = 0 }
    $rainbowChanged = [datetime]::Now
    $nextRainbowSec = Get-Random -Minimum $RainbowStepMin -Maximum ($RainbowStepMax + 1)
    $activeColor    = $AccentColor

    $spinnerFrame = 0
    $startTime    = [datetime]::Now
    $elapsed      = 0.0

    # Header text never changes — build it once
    $headerText = "Waiting ${WaitSec}s to check the progress of the progress bar"
    $headerLeft = [Math]::Max(0, [int](($cw - $headerText.Length) / 2))

    [Console]::CursorVisible = $false
    Clear-Host

    try
    {
        while ($elapsed -lt $WaitSec)
        {
            $now      = [datetime]::Now
            $elapsed  = ($now - $startTime).TotalSeconds
            $progress = [Math]::Min(1.0, $elapsed / $WaitSec)

            if ($IsRainbow -and (($now - $rainbowChanged).TotalSeconds -ge $nextRainbowSec))
            {
                $rainbowIndex   = Get-NextColorIndex -CurrentIndex $rainbowIndex
                $activeColor    = $ColorCycle[$rainbowIndex]
                $rainbowChanged = $now
                $nextRainbowSec = Get-Random -Minimum $RainbowStepMin -Maximum ($RainbowStepMax + 1)
            }

            if (($now - $statusChanged).TotalSeconds -ge 3)
            {
                $statusIndex   = Get-RandomStatusIndex -Statuses $Statuses -CurrentIndex $statusIndex
                $statusChanged = $now
            }

            Write-ClearLine -Row $headerRow -ConsoleWidth $cw
            Set-CursorPos   -X $headerLeft -Y $headerRow
            Write-Host $headerText -ForegroundColor $activeColor -NoNewline

            Write-StatusPanel `
                -TopRow       $panelTopRow `
                -PanelWidth   $panelWidth `
                -Progress     $progress `
                -StatusText   $Statuses[$statusIndex] `
                -SpinnerFrame $spinnerFrame `
                -ElapsedSec   ([int]$elapsed) `
                -TotalSec     $WaitSec `
                -AccentColor  $activeColor

            $spinnerFrame++
            Start-Sleep -Milliseconds $FrameMs
        }

        # Final frame at 100%
        Write-ClearLine -Row $headerRow -ConsoleWidth $cw
        Set-CursorPos   -X $headerLeft -Y $headerRow
        Write-Host $headerText -ForegroundColor $activeColor -NoNewline

        Write-StatusPanel `
            -TopRow       $panelTopRow `
            -PanelWidth   $panelWidth `
            -Progress     1.0 `
            -StatusText   "Here we go again." `
            -SpinnerFrame 0 `
            -ElapsedSec   $WaitSec `
            -TotalSec     $WaitSec `
            -AccentColor  $activeColor
    }
    finally
    {
        [Console]::CursorVisible = $true
    }
}

#endregion

#region --- Entry Point ---

# Invoke-ConsoleSetup   # Disabled - causes resize cursor lock in Windows Terminal

# Enforce parameter minimums
if ($Period   -lt 10) { $Period   = 10 }
if ($Interval -lt 1)  { $Interval = 1  }

$allImages  = @(Get-ImageFiles)
$imageIndex = 0

if ($allImages.Count -gt 1)
{
    $allImages = @($allImages | Sort-Object { Get-Random })
}

if ($FUMode)
{
    $activeStatuses = [string[]]@(
        $FUStatuses | ForEach-Object { $_ -replace '\{TARGET\}', $ExecTargetName }
    )
}
else
{
    $activeStatuses = [string[]]@($StandardStatuses)
}

# 1-in-5 chance rainbow mode auto-activates at startup
$isRainbow = $RainbowMode.IsPresent
if (-not $isRainbow)
{
    $isRainbow = ((Get-Random -Minimum 1 -Maximum 6) -eq 1)
    Write-Verbose "Rainbow auto-trigger: $isRainbow"
}

# Starting color: use specified ImageColor if provided, otherwise pick randomly
$colorIndex = [Array]::IndexOf($ColorCycle, $ImageColor)
if ($colorIndex -lt 0) { $colorIndex = Get-Random -Maximum $ColorCycle.Count }

# If the default was used (user did not explicitly choose), randomize the start
if ($ImageColor -eq 'Cyan')
{
    $colorIndex = Get-Random -Maximum $ColorCycle.Count
}

$runCount = 0

try
{
    do
    {
        # --- Pick image ---
        if ($FUMode)
        {
            $imagePath = $FUImageFile
            $allowFlip = $false
        }
        elseif ($allImages.Count -gt 0)
        {
            $imagePath = $allImages[$imageIndex % $allImages.Count]
            $imageIndex++
            $allowFlip = $true
        }
        else
        {
            $imagePath = $null
            $allowFlip = $true
        }

        $imageLines = [string[]]@(Get-AsciiImage -FilePath $imagePath)

        # Dance color is the current rotation slot.
        # Wait color matches by default; 1-in-5 chance it picks a different slot.
        $danceColor = $ColorCycle[$colorIndex]

        # Re-roll rainbow for the dance phase each pass (unless forced on by -RainbowMode)
        $danceRainbow = $isRainbow
        if (-not $danceRainbow)
        {
            $danceRainbow = ((Get-Random -Minimum 1 -Maximum 6) -eq 1)
        }

        if ((Get-Random -Minimum 1 -Maximum 6) -eq 1)
        {
            $waitColorIndex = ($colorIndex + (Get-Random -Minimum 1 -Maximum $ColorCycle.Count)) `
                              % $ColorCycle.Count
            $waitColor = $ColorCycle[$waitColorIndex]
        }
        else
        {
            $waitColor = $danceColor
        }

        # Wait screen also has its own independent 1-in-5 rainbow roll
        $waitRainbow = $isRainbow
        if (-not $waitRainbow)
        {
            $waitRainbow = ((Get-Random -Minimum 1 -Maximum 6) -eq 1)
        }

        Write-Verbose (
            "Run #$($runCount + 1) | Image: $imagePath | " +
            "DanceColor: $danceColor | WaitColor: $waitColor | " +
            "Rainbow: $isRainbow | WaitRainbow: $waitRainbow | FUMode: $FUMode"
        )

        # --- Step 1: Dance phase (image + status bar) ---
        Invoke-DancePhase `
            -ImageLines  $imageLines `
            -Statuses    $activeStatuses `
            -AccentColor $danceColor `
            -RunPeriod   $Period `
            -IsRainbow   $danceRainbow `
            -AllowFlip   $allowFlip

        $runCount++

        # Advance color for next pass
        $colorIndex = Get-NextColorIndex -CurrentIndex $colorIndex

        # --- Step 2: If Loop = 0, exit. Otherwise show wait screen and repeat. ---
        if ($Loop -gt 0)
        {
            Invoke-WaitPhase `
                -Statuses    $activeStatuses `
                -AccentColor $waitColor `
                -WaitSec     $Loop `
                -IsRainbow   $waitRainbow
        }

    } while ($Loop -gt 0)
}
finally
{
    # Runs on clean exit AND on Ctrl+C
    Clear-Host
    [Console]::CursorVisible = $true
}

#endregion