<#
.AUTHOR
    Apoorv Malmane
	
.SYNOPSIS
    Automated VM Cloning GUI Tool.
 
.DESCRIPTION
    This script provides a graphical user interface (GUI) built with Windows Forms 
    to facilitate bulk cloning of VMware Virtual Machines on a target vCenter server. 
    Users can specify source VM, clone count, target naming prefix, target datastore,
    target ESXi host, disk provisioning, and power-on settings directly from the UI.

.HOW TO USE THE script
	a. 
	1. Copy the script to a Windows machine, Right click and "Run with PowerShell"
	2. Modify the data as needed on UI and Deploy
	3. Add the vCenter Credential in the pop-up

	OR
	
	b. 
	1. Install VMware PowerCLI (First Time Only)
	   Install-Module -Name VMware.PowerCLI -Scope CurrentUser

	2. If your vCenter uses self-signed certificates, ignore invalid certificate warnings by running:
	   Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

	3. Enable Script Execution (First Time Only):
	   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

	4. Execute the Script:
	   cd "$HOME\Desktop"
	   .\DeployVMs.ps1
	
	5. Modify the data as needed on UI and Deploy
	6. Add the vCenter Credential in the pop-up

.DATE
    October 2026
	
.DISCLAIMER: 
	This script is provided "as is", without warranty of any kind and
	without official support.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Create Window ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "VM Deployment Tool"
$form.Size = New-Object System.Drawing.Size(460, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# --- Header / Introductory Text ---
$lblHeader = New-Object System.Windows.Forms.Label
$lblHeader.Location = New-Object System.Drawing.Point(20, 15)
$lblHeader.Size = New-Object System.Drawing.Size(410, 35)
$lblHeader.Text = "Automated VMware VM Deployment Utility`nAuthor: Apoorv Malmane | Configure parameters below to initiate automated cloning."
$lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
$lblHeader.ForeColor = [System.Drawing.Color]::DarkSlateGray
$form.Controls.Add($lblHeader)

# --- Label & Input: Source VM Name ---
$lblSourceVM = New-Object System.Windows.Forms.Label
$lblSourceVM.Location = New-Object System.Drawing.Point(30, 65)
$lblSourceVM.Size = New-Object System.Drawing.Size(180, 20)
$lblSourceVM.Text = "Source VM Name:"
$form.Controls.Add($lblSourceVM)

$txtSourceVM = New-Object System.Windows.Forms.TextBox
$txtSourceVM.Location = New-Object System.Drawing.Point(220, 62)
$txtSourceVM.Size = New-Object System.Drawing.Size(185, 20)
$txtSourceVM.Text = "AM_SourceVM"
$form.Controls.Add($txtSourceVM)

# --- Label & Input: VM Name Prefix ---
$lblPrefix = New-Object System.Windows.Forms.Label
$lblPrefix.Location = New-Object System.Drawing.Point(30, 105)
$lblPrefix.Size = New-Object System.Drawing.Size(180, 20)
$lblPrefix.Text = "New VM Name Prefix:"
$form.Controls.Add($lblPrefix)

$txtPrefix = New-Object System.Windows.Forms.TextBox
$txtPrefix.Location = New-Object System.Drawing.Point(220, 102)
$txtPrefix.Size = New-Object System.Drawing.Size(185, 20)
$txtPrefix.Text = "AM-Cloned-"
$form.Controls.Add($txtPrefix)

# --- Label & Input: Count ---
$lblCount = New-Object System.Windows.Forms.Label
$lblCount.Location = New-Object System.Drawing.Point(30, 145)
$lblCount.Size = New-Object System.Drawing.Size(180, 20)
$lblCount.Text = "Number of clones to build:"
$form.Controls.Add($lblCount)

$numClones = New-Object System.Windows.Forms.NumericUpDown
$numClones.Location = New-Object System.Drawing.Point(220, 142)
$numClones.Size = New-Object System.Drawing.Size(65, 20)
$numClones.Minimum = 1
$numClones.Maximum = 100
$numClones.Value = 2
$form.Controls.Add($numClones)

# --- Label & Input: vCenter Target ---
$lblVC = New-Object System.Windows.Forms.Label
$lblVC.Location = New-Object System.Drawing.Point(30, 185)
$lblVC.Size = New-Object System.Drawing.Size(180, 20)
$lblVC.Text = "Target vCenter Server:"
$form.Controls.Add($lblVC)

$txtVC = New-Object System.Windows.Forms.TextBox
$txtVC.Location = New-Object System.Drawing.Point(220, 182)
$txtVC.Size = New-Object System.Drawing.Size(185, 20)
$txtVC.Text = "10.#.#.#"
$form.Controls.Add($txtVC)

# --- Label & Input: Target ESXi Host ---
$lblHost = New-Object System.Windows.Forms.Label
$lblHost.Location = New-Object System.Drawing.Point(30, 225)
$lblHost.Size = New-Object System.Drawing.Size(180, 20)
$lblHost.Text = "Target ESXi Host:"
$form.Controls.Add($lblHost)

$txtHost = New-Object System.Windows.Forms.TextBox
$txtHost.Location = New-Object System.Drawing.Point(220, 222)
$txtHost.Size = New-Object System.Drawing.Size(185, 20)
$txtHost.Text = "10.#.#.#"
$form.Controls.Add($txtHost)

# --- Label & Input: Target Datastore ---
$lblDS = New-Object System.Windows.Forms.Label
$lblDS.Location = New-Object System.Drawing.Point(30, 265)
$lblDS.Size = New-Object System.Drawing.Size(180, 20)
$lblDS.Text = "Target Datastore:"
$form.Controls.Add($lblDS)

$txtDS = New-Object System.Windows.Forms.TextBox
$txtDS.Location = New-Object System.Drawing.Point(220, 262)
$txtDS.Size = New-Object System.Drawing.Size(185, 20)
$txtDS.Text = "DataStore-10.#.#.#"
$form.Controls.Add($txtDS)

# --- Label & Dropdown: Disk Provisioning ---
$lblDisk = New-Object System.Windows.Forms.Label
$lblDisk.Location = New-Object System.Drawing.Point(30, 305)
$lblDisk.Size = New-Object System.Drawing.Size(180, 20)
$lblDisk.Text = "Disk Provisioning:"
$form.Controls.Add($lblDisk)

$cmbDisk = New-Object System.Windows.Forms.ComboBox
$cmbDisk.Location = New-Object System.Drawing.Point(220, 302)
$cmbDisk.Size = New-Object System.Drawing.Size(185, 20)
$cmbDisk.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$cmbDisk.Items.Add("Thin")
[void]$cmbDisk.Items.Add("Thick")
[void]$cmbDisk.Items.Add("EagerZeroedThick")
$cmbDisk.SelectedItem = "Thin"
$form.Controls.Add($cmbDisk)

# --- Checkbox: Power On after clone ---
$chkPowerOn = New-Object System.Windows.Forms.CheckBox
$chkPowerOn.Location = New-Object System.Drawing.Point(30, 345)
$chkPowerOn.Size = New-Object System.Drawing.Size(300, 25)
$chkPowerOn.Text = "Power on VM after creation"
$chkPowerOn.Checked = $false
$form.Controls.Add($chkPowerOn)

# --- Run Button ---
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Location = New-Object System.Drawing.Point(150, 410)
$btnRun.Size = New-Object System.Drawing.Size(150, 42)
$btnRun.Text = "Start Deployment"

$btnRun.Add_Click({
    $btnRun.Enabled = $false
    $count          = [int]$numClones.Value
    $targetVC       = $txtVC.Text.Trim()
    $targetHostName = $txtHost.Text.Trim()
    $targetDSName   = $txtDS.Text.Trim()
    $diskFormat     = $cmbDisk.SelectedItem.ToString()
    $prefix         = $txtPrefix.Text.Trim()
    $sourceVMName   = $txtSourceVM.Text.Trim()
    $shouldPowerOn  = $chkPowerOn.Checked

    try {
        $vc = Connect-VIServer -Server $targetVC -ErrorAction Stop

        $sourceVM   = Get-VM -Server $vc -Name $sourceVMName -ErrorAction Stop
        $targetHost = Get-VMHost -Server $vc -Name $targetHostName -ErrorAction Stop
        $targetDS   = Get-Datastore -Server $vc -Name $targetDSName -ErrorAction Stop

        1..$count | ForEach-Object {
            $vmName = "$prefix{0:D4}" -f $_

            if ($shouldPowerOn) {
                # Clone synchronously so the VM object is ready to power on
                $newVM = New-VM -Name $vmName `
                                -VM $sourceVM `
                                -VMHost $targetHost `
                                -Datastore $targetDS `
                                -DiskStorageFormat $diskFormat `
                                -Server $vc `
                                -ErrorAction Stop
                Start-VM -VM $newVM -Confirm:$false -RunAsync
            }
            else {
                # Asynchronously trigger clones without powering on
                New-VM -Name $vmName `
                       -VM $sourceVM `
                       -VMHost $targetHost `
                       -Datastore $targetDS `
                       -DiskStorageFormat $diskFormat `
                       -Server $vc `
                       -RunAsync `
                       -ErrorAction Stop
            }
        }

        $statusMsg = "Successfully processed $count VM clone(s) from '$sourceVMName' ($diskFormat) on host '$targetHostName' and datastore '$targetDSName'."
        if ($shouldPowerOn) {
            $statusMsg += "`nPower-on tasks were initiated."
        }
        [System.Windows.Forms.MessageBox]::Show($statusMsg, "Success", "OK", "Information")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error")
    }
    finally {
        $btnRun.Enabled = $true
    }
})
$form.Controls.Add($btnRun)

# --- Display Form ---
$form.ShowDialog() | Out-Null
