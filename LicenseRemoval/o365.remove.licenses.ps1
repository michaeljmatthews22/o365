#powershell - run on ADFS1
#This script removes licenses from those who are not eligable for those licenses.  However this does not remove 
#the actual account.  It only removes the licenses. 
#the password for any "person" user is "W3ar33dgy!"

Import-Module MSOnline
$securePassword = ConvertTo-SecureString "W3ar33dgy!" -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential("mjm287@byucommtest.onmicrosoft.com", $securePassword)
Connect-MsolService -Credential $credentials
$msolUsers = (Get-MsolUser -All)
$currentusers = import-csv D:\Stage\CurrentUsers.stage\ActiveUsers.txt

$haslicense = @()
$dontremove = @()
$takeaway = @()
$needtoremove = @()


#This is the email that would be sent out in case of a failure
$From = "michaeljmatthews@byu.edu"
$To = "office365admin@byu.edu"
$Cc = "michaeljmatthews22@gmail.com"
$Subject = "TEST THIS SCRIPT FAILED TEST TEST"
$Body = "THIS IS A TEST- SCRIPT FAILED"
$SMTPServer = "gateway.byu.edu"
$SMTPPort = "25"


#In order to speed up the script this function only gets those who have licenses and not all users 
#This puts the MSOLusers in the correct format of "userprincipalname" into the array of $haslicense
foreach ($usersFound in $msolusers){
if ($usersFound -ne $null) {
        if($usersFound.isLicensed) {
           $haslicense += $usersFound.userprincipalname     
}}}

#this puts the activeusers in the correct format of "userprincipalname" into the array of $activeusers
foreach ($actualuser in $currentusers) {
    ($activeusers += $actualuser.UserPrincipalName)
}

#This compares the two lists. If someone is licensesed but isn't on the "active users" their license is then put into the $needtoremove array
foreach ($needremoving in $haslicense)
{
    if (!($activeusers -match $needremoving))
        {
           $needtoremove += $needremoving
        }
}
#This is a check.  In theory, if someone is in the $needtoremove they shouldn't be in the $activeusers.  If they are 
#they are then put into the $dontremove array.  If that array exceeds one person, the script stops.
foreach ($double in $needtoremove)
{
    if ($activeusers -match $double)
        {
           $dontremove += $double  
        }
}

if ($dontremove.length -ge 1)
{
Write-host "This script failed"
break
}
else
{
write-host "This script will now remove the licenses"
}

#This serves as a douple check.  If $needtoremove exceeds a certain number the script will stop
if ($needtoremove.length -ge 20)
{
Write-host "You are trying to remove too many users at once.  This script will not function correctly"
Send-MailMessage -From $From -to $To -Cc $Cc -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl 
break
}

#This does the actual removal of the licenses
for($i = 0; $i -lt $needtoremove.Length; $i++) {
    Set-MsolUserLicense -UserPrincipalName $needtoremove[$i] -RemoveLicenses byucommtest:EXCHANGESTANDARD_ALUMNI
} 
for($i = 0; $i -lt $needtoremove.Length; $i++) {
    Set-MsolUserLicense -UserPrincipalName $needtoremove[$i] -RemoveLicenses byucommtest:EXCHANGESTANDARND_STUDENT  
} 

#This serves as a third check.  If a certain license has dropped signficantly then the script will restore licenses to users
$giveback = @()
$giveback += Get-MsolAccountSku

if ($giveback[3].ConsumedUnits -le 15){
write-host "error"
$needtoremove | foreach-object{
for($i = 0; $i -lt $needtoremove.Length; $i++) {
    Set-MsolUserLicense -UserPrincipalName $needtoremove[$i] -AddLicenses byucommtest:EXCHANGESTANDARD_ALUMNI
}}}
else
{
write-host "Success"
}
