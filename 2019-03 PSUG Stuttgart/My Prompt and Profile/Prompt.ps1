function prompt {
    $StartChar = [char]0x25BA
    # Time block - dark grey
    $ColorParams = @{
        "ForegroundColor" = "Gray"; 
        "BackgroundColor" = "DarkGray"
    }
    Write-Host @ColorParams -NoNewline -Object "$StartChar$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') "
    
    # Identity block - gray with colored text
    $ColorParams = @{
        "ForegroundColor" = "Black"; 
        "BackgroundColor" = "Gray"
    }
    Write-Host @ColorParams -NoNewline -Object "$StartChar["
    if($TextIsAdmin) {
        Write-Host -ForegroundColor DarkRed -BackgroundColor Gray -NoNewline "$($TextIsAdmin)$($env:USERNAME)"
    } else {
        Write-Host @ColorParams -NoNewline $env:USERNAME
    }
    Write-Host @ColorParams -NoNewline -Object "]on[$($env:COMPUTERNAME)]in[PID $PID] "
    #Write-Host @ColorParams -NoNewline -Object "$StartChar[$($TextIsAdmin)$($env:USERNAME)]on[$($env:COMPUTERNAME)]in[PID $PID] "

    # Location block - white with colored text
    switch ($PWD.Provider.Name) {
        "FileSystem"  { $ColorParams = @{"ForegroundColor" = "black"      ; "BackgroundColor" = "White"} }
        "Registry"    { $ColorParams = @{"ForegroundColor" = "DarkCyan"   ; "BackgroundColor" = "White"} }
        "Certificate" { $ColorParams = @{"ForegroundColor" = "Blue"       ; "BackgroundColor" = "White"} }
        "Alias"       { $ColorParams = @{"ForegroundColor" = "DarkMagenta"; "BackgroundColor" = "White"} }
        "Environment" { $ColorParams = @{"ForegroundColor" = "DarkMagenta"; "BackgroundColor" = "White"} }
        "Function"    { $ColorParams = @{"ForegroundColor" = "DarkMagenta"; "BackgroundColor" = "White"} }
        "Variable"    { $ColorParams = @{"ForegroundColor" = "DarkMagenta"; "BackgroundColor" = "White"} }
        "WSMan"       { $ColorParams = @{"ForegroundColor" = "DarkMagenta"; "BackgroundColor" = "White"} }
        default       { $ColorParams = @{"ForegroundColor" = "black"      ; "BackgroundColor" = "White"} }
    }
    Write-Host @ColorParams -NoNewline -Object "$StartChar$($PWD) "

    #break line and prompt for console input
    Write-Output "`n$(if (Test-Path variable:/PSDebugContext) { '[DBG]' } else { '' })$('>' * ($nestedPromptLevel + 1))"
}
