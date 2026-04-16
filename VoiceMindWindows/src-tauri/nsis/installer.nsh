; VoiceMind NSIS installer hooks
; Add Windows Firewall rule during installation so iOS devices can connect.

!macro customInstall
    ; Add inbound TCP firewall rule for VoiceMind
    nsExec::ExecToStack 'netsh advfirewall firewall add rule name="VoiceMind" dir=in action=allow program="$INSTDIR\VoiceMind.exe" protocol=TCP localport=8765 enable=yes profile=any'
    Pop $0
    Pop $1
    ${If} $0 == 0
        DetailPrint "Firewall rule added successfully"
    ${Else}
        DetailPrint "Warning: Could not add firewall rule (error $0): $1"
    ${EndIf}
!macroend

!macro customUnInstall
    ; Remove firewall rule when uninstalling
    nsExec::ExecToStack 'netsh advfirewall firewall delete rule name="VoiceMind"'
    Pop $0
    Pop $1
!macroend
