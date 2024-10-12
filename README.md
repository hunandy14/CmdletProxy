完美轉發 PowerShell Cmdlet 函式
===

快速使用

```ps1
# 獲取 Get-Item 函式塊
$scriptContent = CmdletProxy 'Get-Item' -ParamNameScriptBlock @{
    Path = {
        $_ = $_ -replace '`', '``'
    }
    LiteralPath = {
        $_ = $_
    }
} -PipelineScriptBlock {
    $_ = $_ -replace '`', '``'
}

# 執行該修改過後的塊
& $scriptContent '.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'

# 執行該修改過後的塊(管道)
'.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'|& $scriptContent

```

你可以通過 ParamNameScriptBlock 設置各項函式轉發  
設置是一個哈西表，對應到參數名稱與要值入的回條函式  
管道則是由 PipelineScriptBlock 設置，這個單純就只是一個塊而已  

> 例子中的範例是修正 Get-Item 必須要多一層跳脫字元的痛點

<br>

最後一個是註冊函式 NewFunctionName 若使用該參數會直接註冊到環境中  
不會返回函式塊，只會返回該函式的 Get-Command 資訊  

```ps1
# 註冊 Get-ItemFix 函式
$scriptContent = CmdletProxy 'Get-Item' -ParamNameScriptBlock @{
    Path = { $_ = $_ -replace '`', '``' }
} -NewFunctionName Get-ItemFix

# 執行註冊的新函式
Get-ItemFix '.\test\File```[[0-9]`].txt','.\test\File```[0-1`].txt'

```



<br><br><br>

## 技術細節
具體實現的辦法是利用這兩行  

```ps1
# 取得指定命令的元數據
$commandMetadata = [Management.Automation.CommandMetadata]::new((Get-Command $CmdletName))
$proxyScript = [string]([Management.Automation.ProxyCommand]::Create($commandMetadata))
```

可以獲取到原生函式的[轉發介面原始碼](https://github.com/hunandy14/CmdletProxy/blob/main/function/Get-Item.ps1)  
有原始碼就好好辦了，動態插入代碼就可以實現代理了  
這邊對於 Get-Item 的 Path 參數修改是在[第61行](https://github.com/hunandy14/CmdletProxy/blob/main/function/Get-ItemProxy.ps1#L61)  
對於管道參數的修改是在[第79行](https://github.com/hunandy14/CmdletProxy/blob/main/function/Get-ItemProxy.ps1#L79)  

一個讓我比較猶豫的點是使用了內建變數 $_ 來當作類閉包的注入參數  
缺點就是編譯器會跳警告，暫時沒有更好的想法先這樣放著了  
