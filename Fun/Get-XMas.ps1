# inspired by: 
# http://forums.microsoft.com/TechNet-FR/ShowPost.aspx?PostID=2555221&SiteID=45 
$notes = @'
  4A4 4A4 2A4 4A4 4A4 2A4 4A4 4C4 4F3 8G3 1A4 
  4Bb4 4Bb4 4Bb4 8Bb4 4Bb4 4A4 4A4 8A4 8A4 4A4 4G3 4G3 4A4 2G3 2C4 
  4A4 4A4 2A4 4A4 4A4 2A4 4A4 4C4 4F3 4G3 1A4 4Bb4 4Bb4 4Bb4 4Bb4 
  4Bb4 4A4 4A4 8A4 8A4 4C4 4C4 4Bb4 4G3 1F3 4C3 4A4 4G3 4F3 2C3 8C3 8C3  
  4C3 4A4 4G3 4F3 1D3 4D3 4Bb4 4A4 4G3 1E3 4C4 4C4 4Bb4 4G3 
  1A4 4C3 4A4 4G3 4F3 1C3 4C3 4A4 4G3 4F3 1D3 
  4D3 4Bb3 4A4 4G3 4C4 4C4 4C4 8C4 8C4 4D4 4C4 4Bb4 4G3 4F3 2C4 4A4 4A4 2A4 
  4A4 4A4 2A4 4A4 4C4 4C3 8G3 1A4 4Bb4 4Bb4 4Bb4 8Bb4 4Bb4 4A4 4A4 8A4 8A4 
  4A4 4G3 4G3 4A4 2G3 2C4 4A4 4A4 2A4 4A4 4A4 2A4 4A4 4C4 4F3 8G3 
  1A4 4Bb4 4Bb4 4Bb4 4Bb4 4Bb4 4A4 4A4 8A4 8A4 4C4 4C4 4Bb4 4G3 1F3
'@ 
 
# Note is given by fn=f0 * (a)^n 
# a is the twelth root of 2 
# n is the number of half steps from f0, positive or negative 
# f0 used here is A4 at 440 Hz 
 
$StandardDuration = 1000
$f0 = 440
$a = [math]::pow(2,(1/12)) # Twelth root of 2
 
function Get-Frequency([string]$note)
{
  # n is the number of half steps from the fixed note
  $null = $note -match '([A-G#]{1,2})(\d+)'
  $octave = ([int] $matches[2]) - 4;
  $n = $octave * 12 + ( Get-HalfSteps $matches[1] );
  $f0 * [math]::Pow($a, $n);
}
 
function Get-HalfSteps([string]$note)
{
  switch($note)
  {
    'A'  { 0 }
    'A#' { 1 }
    'Bb' { 1 }
    'B'  { 2 }
    'C'  { 3 }
    'C#' { 4 }
    'Db' { 4 }
    'D'  { 5 }
    'D#' { 6 }
    'Eb' { 6 }
    'E'  { 7 }
    'F'  { 8 }
    'F#' { 9 }
    'Gb' { 9 }
    'G'  { 10 }
    'G#' { 11 }
    'Ab' { 11 }
  }
}
 
$notes.Split(' ') | ForEach-Object {
 
  if ($_ -match '(\d)(.+)')
  {
    $duration = $StandardDuration / ([int]$matches[1])
    $playNote = $matches[2]
    $freq = Get-Frequency $playNote
 
    [console]::Beep( $freq, $duration)
    Start-Sleep -Milliseconds 50
  }
}