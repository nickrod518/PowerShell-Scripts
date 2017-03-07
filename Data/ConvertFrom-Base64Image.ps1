$Base64Icon = ''
$IconStream = [System.Convert]::FromBase64String($Base64Icon)
$IconBMP = [System.Drawing.Image]::FromStream($IconStream)