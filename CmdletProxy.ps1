# 動態代理函式
function CmdletProxy {
    param (
        [string]$CmdletName,
        [hashtable]$ParamNameScriptBlock
    )
    
    $commandMetadata = [Management.Automation.CommandMetadata]::new((Get-Command $CmdletName))
    $commandScript = [string]([Management.Automation.ProxyCommand]::Create($commandMetadata))
    
    $script = ($ParamNameScriptBlock.GetEnumerator() |ForEach-Object {
        $key = $_.key
        $value = $_.value.ToString().Trim()
        @"
        if (`$PSBoundParameters.TryGetValue('$key', [ref]`$$($key.ToLower())))
        {
            `$_ = `$PSBoundParameters['$key']
            $value
            `$PSBoundParameters['$key'] = `$_
        }
"@
    } ) -join "`r`n"
    
    $refMark = "        if (`$PSBoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer))"
    $proxyScript = $commandScript.Replace($refMark, ($script+"`r`n"+$refMark))
    
    [ScriptBlock]::Create($proxyScript)
    
}

# 生成替換後的代理函式
$scriptContent = CmdletProxy 'Get-Item' -ParamNameScriptBlock @{
    Path = {
        $_ = $_.Replace('`','``')
    }
    LiteralPath = {
        $_ = $_
    }
}

# 測試代理函式
$scriptContent > '.\test\Get-Item-test.ps1'
& $scriptContent '.\test\File```[[0-9]`].txt'
