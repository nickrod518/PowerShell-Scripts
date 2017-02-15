$PriceData = [System.Collections.Specialized.OrderedDictionary]@{}

$Data = (Invoke-RestMethod -Method Get -Uri 'https://api.coindesk.com/v1/bpi/historical/close.json' `
    -ContentType 'application/json').bpi | Out-String

$Data.Trim() -split "`r`n" | ForEach-Object {
    $line = $_ -split ' : '
    $PriceData.Add($line[0], $line[1])
}

[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.Datavisualization")


$Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$Chart.Width = 650
$Chart.Height = 400

$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$Chart.ChartAreas.Add($ChartArea)

# Set the chart formatting options
[void]$Chart.Titles.Add('Bitcoin Price History (30 day)')
$ChartArea.AxisX.Title = 'Date'
$ChartArea.AxisY.Title = 'Price (USD)'
$Chart.Titles[0].Font = New-Object System.Drawing.Font('Arial', 18, [System.Drawing.FontStyle]::Bold)
$ChartArea.AxisX.TitleFont = New-Object System.Drawing.Font('Arial', 12)
$ChartArea.AxisY.TitleFont = New-Object System.Drawing.Font('Arial', 12)
$ChartArea.AxisY.Interval = 50
$ChartArea.AxisX.Interval = 1
$ChartArea.AxisY.IsStartedFromZero = 0

# Data series
[void]$Chart.Series.Add('Price')
$Chart.Series['Price'].ChartType = "Line"
$Chart.Series['Price'].BorderWidth = 3
$Chart.Series['Price'].ChartArea = "ChartArea1"
$Chart.Series['Price'].Color = "#62B5CC"
$Chart.Series['Price'].Points.DataBindXY($PriceData.Keys, $PriceData.Values)

# Display the chart on a form 
$Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Right -bor 
    [System.Windows.Forms.AnchorStyles]::Top -bor 
    [System.Windows.Forms.AnchorStyles]::Left
$Form = New-Object Windows.Forms.Form
$Form.Text = "Bitcoin Price Chart"
$Form.Width = 660
$Form.Height = 440
$Form.Controls.Add($Chart)
$Form.Add_Shown({ $Form.Activate() })
$Form.ShowDialog()