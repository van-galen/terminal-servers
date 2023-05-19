####################### SCHEDULE TASK EVERY 5 MINUTES
####################### run using gmsa
function Set-runbetter ($jawn, $scratchpath, $connectionbroker) {

    $jawnhost = $jawn.sessionhost 
    $jawnlogpath = "\\$jawnhost\$scratchpath"

    # log current cpu load
    Get-WmiObject -ComputerName $jawn.sessionhost win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object -ExpandProperty Average | Out-File -FilePath $jawnlogpath -Append
    
    #on get average, if ge 60 kick it out
    if ($jawn.NewConnectionAllowed -eq "yes") {
        
        $cpulogavg = (Get-Content -Path $jawnlogpath -Tail 3 | Measure-Object -Average).Average
                
        if ($cpulogavg -ge 60) {
            #kicking sessions 
            $results = Invoke-Command -ComputerName $jawnhost { quser } | Where-Object { $_ -match "Disc" }
            foreach ($result in $results) {       
                $userInfo = @{
                    "sessionID" = [int] $result.substring(40, 4).trim()
                }
                #Write-Host $userInfo.sessionID
                Invoke-Command -ComputerName $jawnhost { logoff $args[0] } -ArgumentList $userInfo.sessionID
            }

            ####HERE IS WHERE IT SETS CONNECT VALUE TO FALSE
            Set-RDSessionHost -SessionHost $jawnhost -ConnectionBroker $connectionbroker -NewConnectionAllowed No 
                        
            # SEND ALERT TO TEAM $jawn.sessionhost out of rotation
            Send-MailMessage -From '[pass variable or add your info]' -To '[]' -Subject "terminal server - $jawnhost out of rotation" -body "$jawnhost out of rotation" -smtp '[]'           
        }
    }

    #off get average, if le 40 add back in
    If ($jawn.NewConnectionAllowed -eq "no") {
        $cpulogavg = (Get-Content -Path $jawnlogpath -Tail 3 | Measure-Object -Average).Average
        if ($cpulogavg -le 40) {
            #ADD BACK INTO ROTATION       
            Set-RDSessionHost -SessionHost $jawnhost -ConnectionBroker $connectionbroker -NewConnectionAllowed Yes  
            Send-MailMessage -From '[]' -To '[]' -Subject "terminal server - $jawnhost RETURNS" -body "$jawnhost RETURNED to rotation" -smtp '[]'
        }
    }
    
    ### log cleanup
    $jawncontent = Get-Content -Path $jawnlogpath | Measure-Object -Line
    if ($jawncontent.lines -gt "2016") {
        $errythingbut1 = Get-Content -Path $jawnlogpath | Select-Object -Skip 1  
        $errythingbut1 | Out-File -FilePath "$jawnlogpath"

    }
	
}

function log-putback ($jawn, $scratchpath, $connectionbroker) {

    $jawnhost = $jawn.sessionhost 
    $jawnlogpath = "\\$jawnhost\$scratchpath"

    # log current cpu load
        Get-WmiObject -ComputerName $jawn.sessionhost win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object -ExpandProperty Average | Out-File -FilePath $jawnlogpath -Append
    
        #ADD BACK INTO ROTATION and ALERT      
        Set-RDSessionHost -SessionHost $jawnhost -ConnectionBroker $connectionbroker -NewConnectionAllowed Yes  
        Send-MailMessage -From '[]' -To '[]' -Subject "servers are looking GRIM - $jawnhost RETURNS" -body "$jawnhost RETURNED to rotation" -smtp '[]'
        
    ### log cleanup
    $jawncontent = Get-Content -Path $jawnlogpath | Measure-Object -Line
    if ($jawncontent.lines -gt "2016") {
        $errythingbut1 = Get-Content -Path $jawnlogpath | Select-Object -Skip 1  
        $errythingbut1 | Out-File -FilePath "$jawnlogpath"

    }
	
}

########## the actual work

workflow set-balance ($scratchpath, [string]$connectionbroker, [string]$collectionname) {
    # this gets everything, fine if you only have one collection
    #$Nodes = Get-RDSessionCollection -ConnectionBroker $connectionbroker | Select-Object -Property collectionname | ForEach-Object -Process { Get-RDSessionHost -ConnectionBroker $connectionbroker -CollectionName $_.collectionname | Sort-Object }

    # collection specific
    $Nodes = Get-RDSessionHost -ConnectionBroker $connectionbroker -CollectionName $collectionname

    $ActiveNodes = $Nodes | Where-Object { $_.NewConnectionAllowed -eq "Yes" }

    if ($ActiveNodes.Count -ge 2 ) {

        foreach -parallel ($node in $nodes) {

            Set-runbetter $node $scratchpath $connectionbroker

        }
    }

    if ($ActiveNodes.Count -lt 2 ) {

        foreach -parallel ($node in $nodes) {

            # set everything true
            log-putback $node $scratchpath $connectionbroker

        }
    }
}

# set-balance $scratchpath $brokernamefqdn $collectionname
# set-balance C$\Windows\Temp\cpucount hostname.fq.domain "lovely server collection"
