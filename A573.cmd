<# :
@echo off
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Command "IEX (Get-Content '%~f0' | Out-String)"
exit /b
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$myIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress | Select-Object -First 1

$form = New-Object Windows.Forms.Form
$form.Text = "A573"
$form.Size = "400, 520"
$form.StartPosition = "CenterScreen"

$infoLabel = New-Object Windows.Forms.Label
$infoLabel.Text = "Your IP: $myIP"
$infoLabel.Location = "20, 10"; $infoLabel.Size = "345, 20"; $infoLabel.Font = New-Object Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($infoLabel)

$ipInput = New-Object Windows.Forms.TextBox
$ipInput.Text = "127.0.0.1"; $ipInput.Location = "20, 40"; $ipInput.Size = "200, 20"
$form.Controls.Add($ipInput)

$hostBtn = New-Object Windows.Forms.Button
$hostBtn.Text = "RECEIVE"; $hostBtn.Location = "230, 38"; $hostBtn.Size = "130, 25"
$form.Controls.Add($hostBtn)

$dropZone = New-Object Windows.Forms.Label
$dropZone.Text = "DRAG FILE HERE"; $dropZone.TextAlign = "MiddleCenter"
$dropZone.Location = "20, 80"; $dropZone.Size = "345, 200"; $dropZone.BorderStyle = "FixedSingle"; $dropZone.AllowDrop = $true
$form.Controls.Add($dropZone)

$sendBtn = New-Object Windows.Forms.Button
$sendBtn.Text = "SEND FILE"; $sendBtn.Location = "20, 350"; $sendBtn.Size = "345, 45"; $sendBtn.BackColor = "LightBlue"
$form.Controls.Add($sendBtn)

$status = New-Object Windows.Forms.Label
$status.Text = "Status: Idle"; $status.Location = "20, 310"; $status.Size = "345, 20"
$form.Controls.Add($status)

$script:selectedFilePath = ""
$port = 9001

$dropZone.Add_DragEnter({ if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = "Copy" } })
$dropZone.Add_DragDrop({
    $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
    $script:selectedFilePath = $files[0]
    $dropZone.Text = "FILE: " + [System.IO.Path]::GetFileName($script:selectedFilePath)
    $dropZone.BackColor = "PaleGreen"
})

$hostBtn.Add_Click({
    $hostBtn.Enabled = $false
    $status.Text = "Status: LISTENING... (App will freeze until file arrives)"
    $form.Refresh() # Force UI update
    
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
        $listener.Start()
        
        # This will pause the app until the sender connects
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        
        $savePath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Received_Data.bin"
        $fs = New-Object System.IO.FileStream($savePath, [System.IO.FileMode]::Create)
        
        $buffer = New-Object Byte[] 65536
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fs.Write($buffer, 0, $read)
        }
        
        $fs.Close(); $client.Close(); $listener.Stop()
        [Windows.Forms.MessageBox]::Show("Success! File saved to Desktop as 'Received_Data.bin'")
    } catch {
        [Windows.Forms.MessageBox]::Show("Error: " + $_.Exception.Message)
    } finally {
        $hostBtn.Enabled = $true
        $status.Text = "Status: Idle"
    }
})

$sendBtn.Add_Click({
    if ($script:selectedFilePath -eq "") { [Windows.Forms.MessageBox]::Show("Drag a file first!"); return }
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        # Attempt to connect with a 5-second timeout
        $connect = $client.BeginConnect($ipInput.Text, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
        
        if (-not $wait) { throw "Connection timed out. Is the Receiver hosting?" }
        
        $client.EndConnect($connect)
        $stream = $client.GetStream()
        
        $fs = [System.IO.File]::OpenRead($script:selectedFilePath)
        $buffer = New-Object Byte[] 65536
        while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $stream.Write($buffer, 0, $read)
        }
        
        $fs.Close(); $client.Close()
        [Windows.Forms.MessageBox]::Show("File Sent!")
    } catch {
        [Windows.Forms.MessageBox]::Show("Connection Failed: " + $_.Exception.Message)
    }
})

$form.ShowDialog()