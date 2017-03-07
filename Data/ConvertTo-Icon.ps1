$IconBMP = [System.Drawing.Image]::FromStream($IconStream)
$IconBMP.MakeTransparent()
$Hicon = $IconBMP.GetHicon()
$IconBMP = [System.Drawing.Icon]::FromHandle($Hicon)