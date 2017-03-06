# Create Key that is easy to copy and paste
$Key = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$CopiableKey = '$Key = ('
$Key.GetEnumerator() | ForEach-Object {
    $CopiableKey += "$_,"
}
$CopiableKey = $CopiableKey.TrimEnd(',')
Write-Host "$CopiableKey)`n"

# Create a password, encrypt it, and save to a file
$PasswordFile = New-Item -ItemType File '.\Password.txt' -Force
$Password = Read-Host 'Password to encrypt' | ConvertTo-SecureString -AsPlainText -Force
$Password | ConvertFrom-SecureString -Key $Key | Out-File $PasswordFile
Write-Host "Your password file is saved to $($PasswordFile.FullName)."

<# Use this to decrypt password
    $EncryptedPassword = Get-Content $PasswordFile | ConvertTo-SecureString -Key $Key
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedPassword)
    $UnencryptedPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
#>

Pause