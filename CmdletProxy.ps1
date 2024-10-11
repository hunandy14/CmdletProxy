# 動態代理函式
function CmdletProxy {
    param (
        [Parameter(Position = 0, Mandatory)]
        [string]$CmdletName,
        [Parameter(Position = 1)]
        [hashtable]$ParamNameScriptBlock,
        [scriptblock]$PipelineScriptBlock,
        [string]$NewFunctionName
    )
    
    # 取得指定命令的元數據
    $commandMetadata = [Management.Automation.CommandMetadata]::new((Get-Command $CmdletName))
    $proxyScript = [string]([Management.Automation.ProxyCommand]::Create($commandMetadata))
    
    # 構建參數處理腳本
    $paramScript = ($ParamNameScriptBlock.GetEnumerator() | ForEach-Object {
        $key = $_.key
        $value = $_.value.ToString().Trim()
        @"
        if (`$PSBoundParameters.TryGetValue('$key', [ref]`$$($key.ToLower())) )
        {
            `$_ = `$PSBoundParameters['$key']
            $value
            `$PSBoundParameters['$key'] = `$_
        }
"@
    }) -join "`r`n"
    
    # 替換代理參數腳本
    if ($paramScript) {
        $refMark = "        if (`$PSBoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer))"
        $replace = $paramScript + "`r`n$refMark"
        $proxyScript = $proxyScript.Replace($refMark, $replace)
    }
    
    # 替換代理管道腳本
    if ($PSBoundParameters.ContainsKey('PipelineScriptBlock')) {
        $refMark = "`$steppablePipeline.Process(`$_)"
        $replace = $PipelineScriptBlock.ToString().trim() + "`r`n        $refMark"
        $proxyScript = $proxyScript.Replace($refMark, $replace)
    }
    
    # 動態注冊新的函式()
    if ($NewFunctionName) {
        Set-Item -Path Function:Script:$NewFunctionName -Value $proxyScript
        return Get-Command -Name $NewFunctionName
    }
    
    # 返回參數處理腳本塊
    [ScriptBlock]::Create($proxyScript)
    
}



# # 生成替換後的代理函式區塊
# $scriptContent = CmdletProxy 'Get-Item' -ParamNameScriptBlock @{
#     Path = {
#         $_ = $_ -replace '`', '``'
#     }
#     LiteralPath = {
#         $_ = $_
#     }
# } -PipelineScriptBlock {
#     $_ = $_ -replace '`', '``'
# } # -NewFunctionName Get-ItemFix

# # 測試註冊的函式(-NewFunctionName)
# # Get-ItemFix '.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'

# # 測試代理函式
# $scriptContent > '.\test\Get-ItemTest.ps1'
# & $scriptContent '.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'
# '.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'|& $scriptContent
