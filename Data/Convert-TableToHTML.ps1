# You can embed the css in the script or alternatively you can reference a css file

# File reference
$Message = $Table | ConvertTo-Html -CssUri $CSSFilePath | Out-String

# Embed
$CSS = @"
    <style>
        h1, h5, th { text-align: center; }
        table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
        th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; }
        td { font-size: 11px; padding: 5px 20px; color: #000; }
        tr { background: #b8d1f3; }
        tr:nth-child(odd) { background: #b8d1f3; }
        tr:nth-child(even) { background: #dae5f4; }
    </style>
"@
$Message = $Table | ConvertTo-Html -Head $CSS | Out-String

# And then use this to send the email
Send-MailMessage -Body $Message -BodyAsHtml -From 'Alerts@company.com' `
    -SmtpServer smtp.company.local -Subject 'Report' -To 'me@company.com'