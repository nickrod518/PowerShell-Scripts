Add-Type -AssemblyName System.Windows.Forms

# Get the Base64 string of an image from here https://www.base64-image.de/ and paste below
$Base64Icon = ''
$IconStream = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Icon)
$IconBMP = [System.Drawing.Bitmap][System.Drawing.Image]::FromStream($IconStream)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Test Title'
$form.Size = '640, 480'
$form.FormBorderStyle='FixedToolWindow'
$form.StartPosition='CenterScreen'

$image=New-Object Windows.Forms.PictureBox
$image.Size='256,256'
$image.Image = $IconBMP
$image.Location='50,50'
$form.controls.add($image)

$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()