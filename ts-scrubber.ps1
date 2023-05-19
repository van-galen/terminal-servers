### run as scheduled task
### checks and sends disk space summary across nodes, if disk space below 10% threshold deletes profiles to free up space
### delprof2.exe care of: https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/

function delete-inactiveprofiles {
    param ($connectionbroker, $collectionname, $delprofshare, $foldername)
    
    $Nodes = Get-RDSessionHost -ConnectionBroker $connectionbroker -CollectionName $collectionname
  
    $hash = $null
    $hash = @{}
  
    $GoodNodes = $nodes.SessionHost
  
    foreach ($node in $GoodNodes){
  
        $targetdisk = invoke-command -ComputerName $node -ScriptBlock {$env:systemdrive}
  
        $osdisk = $targetdisk.substring(0, 1)
        
        $wintsshare = "\\$node\$osdisk$\$foldername\profilecleanup"
        
        # copy delprof to location on that disk
        robocopy /r:1 /w:3 $delprofshare $wintsshare
  
        # get disk info
        $gimmegb = Invoke-Command -ComputerName $node -scriptblock {Get-CimInstance -Class Win32_LogicalDisk | Where-Object {$_.Deviceid -like "$Using:targetdisk"}} 
        $cent = $null
        $cent = $gimmegb.FreeSpace/$gimmegb.Size
        
        # clear and create hashtable
        
        $hash.add($node,$cent)
  
  
      if ($cent -ne $null){
          if ($cent -le ".10") {
            $gnarlypath = "$targetdisk\$foldername\profilecleanup\delprof2.exe"
            Send-MailMessage -From '[email or variable]' -To '[to email or variable]' -Subject "TS - 10% space profile deletion $node" -body "inactive profile deletion START" -smtp '[smtp handling]'
            Invoke-Command -ComputerName $node -scriptblock {cmd /c "$Using:gnarlypath /d:1 /q /ntuserini /i"}
            Send-MailMessage -From '[email or variable]' -To '[to email or variable]' -Subject "TS - 10% space profile deletion $node" -body "inactive profile deletion COMPLETE" -smtp '[smtp handling]'
          }      
      }
  
    }
  
    $tsmailbody = $hash.GetEnumerator() | sort Name  
    $EmailBody += "<table width='100%' border='1'><tr><td><b>NODE</b></td><td><b>FREE DISK</b></td></tr>"    
    foreach ($entry in $tsmailbody){$EmailBody += "<tr><td>$($entry.Key)</td><td>$($entry.Value)</td></tr>"}
    $EmailBody += "</table><br /><p>empty cells mean server is not reachable</p>"
  
    Send-MailMessage -From '[email or variable]' -To '[to email or variable]' -Subject "space check" -BodyAsHtml -body $emailbody -smtp '[smtp handling]'
  
  }
  
# delete-inactiveprofiles $connectionbroker $collectionname $delprofshare $foldername
# delete-inactiveprofiles "f.q.d.n" "lovely collection" "delprof2.exe source location" "destination for copied delprof2"
