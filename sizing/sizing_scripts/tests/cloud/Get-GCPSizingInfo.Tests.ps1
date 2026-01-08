$ErrorActionPreference = 'Stop'

# Provide a lightweight stub GoogleCloud module so that
# `#requires -Modules GoogleCloud` in Get-GCPSizingInfo.ps1 can be satisfied
# without needing the real Google Cloud SDK. Pester mocks then override
# the stubbed cmdlets in each test.
$stubRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'GoogleCloudStub'
if (-not (Test-Path $stubRoot)) {
    $moduleDir = Join-Path $stubRoot 'GoogleCloud'
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
    $moduleFile = Join-Path $moduleDir 'GoogleCloud.psm1'
    if (-not (Test-Path $moduleFile)) {
        @'
function Get-GcpProject { throw "GoogleCloud stub: use Pester Mock in tests." }
function Get-GceInstance { throw "GoogleCloud stub: use Pester Mock in tests." }
function Get-GceDisk    { throw "GoogleCloud stub: use Pester Mock in tests." }
'@ | Set-Content -Path $moduleFile -Encoding UTF8
    }
}

if ($env:PSModulePath -notlike "*$stubRoot*") {
    $env:PSModulePath = "$stubRoot$([System.IO.Path]::PathSeparator)$($env:PSModulePath)"
}

Describe 'Get-GCPSizingInfo.ps1' {
    BeforeAll {
        # Resolve script path assuming tests are run from the script directory
        # (sizing/sizing_scripts/cloud on host, /cloud in the Docker image).
        $script:scriptPath = Join-Path (Get-Location) 'Get-GCPSizingInfo.ps1'

        if (-not (Test-Path $script:scriptPath)) {
            throw "Get-GCPSizingInfo.ps1 not found in current directory '$((Get-Location).Path)'. " +
                  "Run tests from the sizing/sizing_scripts/cloud directory."
        }
    }

    It 'creates expected CSV and ZIP for a single project' {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testDir | Out-Null
        Push-Location $testDir
        try {
            # Mock GCP discovery and data collection cmdlets so no real calls are made
            Mock Get-GcpProject {
                [pscustomobject]@{ ProjectId = 'test-project-1' }
            }

            Mock Get-GceInstance {
                [pscustomobject]@{
                    Name   = 'test-vm-1'
                    Zone   = 'projects/test/zones/us-central1-a'
                    Disks  = @([pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-1' })
                    Labels = @{}
                }
            }

            # When Get-GceDisk is called with -DiskName we return the attached disk
            Mock Get-GceDisk {
                param(
                    [string]$Project,
                    [string]$DiskName
                )
                [pscustomobject]@{
                    Name              = $DiskName
                    Project           = $Project
                    Zone              = 'projects/test/zones/us-central1-a'
                    Id                = 'disk-1'
                    SizeGb            = 100
                    DiskEncryptionKey = $null
                    SourceImage       = $null
                    Labels            = @{}
                }
            } -ParameterFilter { $PSBoundParameters.ContainsKey('DiskName') }

            # When Get-GceDisk is called without -DiskName we simulate an unattached disk
            Mock Get-GceDisk {
                param(
                    [string]$Project
                )
                @(
                    [pscustomobject]@{
                        Name              = 'unattached-disk-1'
                        Project           = $Project
                        Zone              = 'projects/test/zones/us-central1-a'
                        Id                = 'udisk-1'
                        SizeGb            = 50
                        DiskEncryptionKey = $null
                        SourceImage       = $null
                        Users             = $null
                        Labels            = @{}
                    }
                )
            } -ParameterFilter { -not $PSBoundParameters.ContainsKey('DiskName') }

            # Sanity check that the script path exists before invoking
            Test-Path $scriptPath | Should -BeTrue

            & $scriptPath -Projects 'test-project-1'

            $zip = Get-ChildItem 'gcp_sizing_results_*.zip' | Select-Object -First 1
            $zip | Should -Not -BeNullOrEmpty

            $extractDir = Join-Path $testDir 'unzipped'
            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

            $vmCsv = Get-ChildItem $extractDir -Filter 'gce_vm_info-*.csv' | Select-Object -First 1
            $vmCsv | Should -Not -BeNullOrEmpty

            $vmData = Import-Csv $vmCsv.FullName
            $vmData.Count | Should -Be 1
            $vmData[0].TotalDiskCount | Should -Be 1
        }
        finally {
            Pop-Location
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    It 'generates anonymized data and mapping when -Anonymize is used' {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testDir | Out-Null
        Push-Location $testDir
        try {
            Mock Get-GcpProject {
                [pscustomobject]@{ ProjectId = 'test-project-1' }
            }

            Mock Get-GceInstance {
                [pscustomobject]@{
                    Name   = 'test-vm-1'
                    Zone   = 'projects/test/zones/us-central1-a'
                    Disks  = @([pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-1' })
                    Labels = @{}
                }
            }

	            Mock Get-GceDisk {
	                param(
	                    [string]$Project,
	                    [string]$DiskName
	                )
	                if ($PSBoundParameters.ContainsKey('DiskName')) {
	                    # Per-disk lookup for attached disk
	                    [pscustomobject]@{
	                        Name              = $DiskName
	                        Project           = $Project
	                        Zone              = 'projects/test/zones/us-central1-a'
	                        Id                = 'disk-1'
	                        SizeGb            = 100
	                        DiskEncryptionKey = $null
	                        SourceImage       = $null
	                        Labels            = @{}
	                    }
	                }
	                else {
	                    # Project-wide disk listing, with one unattached disk
	                    @(
	                        [pscustomobject]@{
	                            Name              = 'unattached-disk-1'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'udisk-1'
	                            SizeGb            = 50
	                            DiskEncryptionKey = $null
	                            SourceImage       = $null
	                            Users             = $null
	                            Labels            = @{}
	                        }
	                    )
	                }
	            }

            # Sanity check that the script path exists before invoking
            Test-Path $scriptPath | Should -BeTrue

            & $scriptPath -Projects 'test-project-1' -Anonymize

            $mapCsv = Get-ChildItem 'gcp_anonymized_keys_to_actual_values-*.csv' | Select-Object -First 1
            $mapCsv | Should -Not -BeNullOrEmpty

            $map = Import-Csv $mapCsv.FullName
            $map.ActualValue | Should -Contain 'test-project-1'

            $zip = Get-ChildItem 'gcp_sizing_results_*.zip' | Select-Object -First 1
            $zip | Should -Not -BeNullOrEmpty

            $extractDir = Join-Path $testDir 'unzipped'
            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

            $vmCsv = Get-ChildItem $extractDir -Filter 'gce_vm_info-*.csv' | Select-Object -First 1
            $vmCsv | Should -Not -BeNullOrEmpty

            $vmData = Import-Csv $vmCsv.FullName
            $vmData.Count | Should -Be 1
            $vmData[0].Project | Should -Not -Be 'test-project-1'
            $vmData[0].Name    | Should -Not -Be 'test-vm-1'
        }
        finally {
            Pop-Location
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

	    It 'computes totals and encrypted disk sizes for multiple VMs and disks' {
	        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
	        New-Item -ItemType Directory -Path $testDir | Out-Null
	        Push-Location $testDir
	        try {
	            Mock Get-GcpProject {
	                [pscustomobject]@{ ProjectId = 'test-project-1' }
	            }

	            # Two VMs with three attached disks total
	            Mock Get-GceInstance {
	                @(
	                    [pscustomobject]@{
	                        Name   = 'vm-1'
	                        Zone   = 'projects/test/zones/us-central1-a'
	                        Disks  = @(
	                            [pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-1' },
	                            [pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-2' }
	                        )
	                        Labels = @{}
	                    },
	                    [pscustomobject]@{
	                        Name   = 'vm-2'
	                        Zone   = 'projects/test/zones/us-central1-a'
	                        Disks  = @(
	                            [pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-3' }
	                        )
	                        Labels = @{}
	                    }
	                )
	            }

	            # Per-disk lookup for attached disks and project-wide listing in a single mock
	            Mock Get-GceDisk {
	                param(
	                    [string]$Project,
	                    [string]$DiskName
	                )
	                if ($PSBoundParameters.ContainsKey('DiskName')) {
	                    # Attached disk lookup
	                    switch ($DiskName) {
	                        'disk-1' {
	                            [pscustomobject]@{
	                                Name              = 'disk-1'
	                                Project           = $Project
	                                Zone              = 'projects/test/zones/us-central1-a'
	                                Id                = 'disk-1-id'
	                                SizeGb            = 100
	                                DiskEncryptionKey = 'enc-1'
	                                SourceImage       = $null
	                                Labels            = @{}
	                            }
	                        }
	                        'disk-2' {
	                            [pscustomobject]@{
	                                Name              = 'disk-2'
	                                Project           = $Project
	                                Zone              = 'projects/test/zones/us-central1-a'
	                                Id                = 'disk-2-id'
	                                SizeGb            = 200
	                                DiskEncryptionKey = $null
	                                SourceImage       = $null
	                                Labels            = @{}
	                            }
	                        }
	                        'disk-3' {
	                            [pscustomobject]@{
	                                Name              = 'disk-3'
	                                Project           = $Project
	                                Zone              = 'projects/test/zones/us-central1-a'
	                                Id                = 'disk-3-id'
	                                SizeGb            = 50
	                                DiskEncryptionKey = 'enc-3'
	                                SourceImage       = $null
	                                Labels            = @{}
	                            }
	                        }
	                    }
	                }
	                else {
	                    # Project-wide disk listing with one unattached disk
	                    @(
	                        [pscustomobject]@{
	                            Name              = 'disk-1'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'disk-1-id'
	                            SizeGb            = 100
	                            DiskEncryptionKey = 'enc-1'
	                            SourceImage       = $null
	                            Users             = @('some-vm')
	                            Labels            = @{}
	                        },
	                        [pscustomobject]@{
	                            Name              = 'disk-2'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'disk-2-id'
	                            SizeGb            = 200
	                            DiskEncryptionKey = $null
	                            SourceImage       = $null
	                            Users             = @('some-vm')
	                            Labels            = @{}
	                        },
	                        [pscustomobject]@{
	                            Name              = 'disk-3'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'disk-3-id'
	                            SizeGb            = 50
	                            DiskEncryptionKey = 'enc-3'
	                            SourceImage       = $null
	                            Users             = @('some-vm')
	                            Labels            = @{}
	                        },
	                        [pscustomobject]@{
	                            Name              = 'unattached-disk-1'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'udisk-1-id'
	                            SizeGb            = 30
	                            DiskEncryptionKey = $null
	                            SourceImage       = $null
	                            Users             = $null
	                            Labels            = @{}
	                        }
	                    )
	                }
	            }

	            Test-Path $scriptPath | Should -BeTrue

	            & $scriptPath -Projects 'test-project-1'

	            $zip = Get-ChildItem 'gcp_sizing_results_*.zip' | Select-Object -First 1
	            $zip | Should -Not -BeNullOrEmpty

	            $extractDir = Join-Path $testDir 'unzipped'
	            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

	            $vmCsv = Get-ChildItem $extractDir -Filter 'gce_vm_info-*.csv' | Select-Object -First 1
	            $vmCsv | Should -Not -BeNullOrEmpty
	            $vmData = Import-Csv $vmCsv.FullName
	            $vmData.Count | Should -Be 2

	            $vm1 = $vmData | Where-Object { $_.Name -eq 'vm-1' }
	            $vm2 = $vmData | Where-Object { $_.Name -eq 'vm-2' }

	            $vm1.TotalDiskCount      | Should -Be 2
	            $vm1.TotalDiskSizeGb     | Should -Be 300
	            $vm1.EncryptedDisksCount | Should -Be 1
	            $vm1.EncryptedDisksSizeGb| Should -Be 100

	            $vm2.TotalDiskCount      | Should -Be 1
	            $vm2.TotalDiskSizeGb     | Should -Be 50
	            $vm2.EncryptedDisksCount | Should -Be 1
	            $vm2.EncryptedDisksSizeGb| Should -Be 50

	            $attachedCsv = Get-ChildItem $extractDir -Filter 'gce_attached_disk_info-*.csv' | Select-Object -First 1
	            $attachedCsv | Should -Not -BeNullOrEmpty
	            (Import-Csv $attachedCsv.FullName).Count | Should -Be 3

	            $unattachedCsv = Get-ChildItem $extractDir -Filter 'gce_unattached_disk_info-*.csv' | Select-Object -First 1
	            $unattachedCsv | Should -Not -BeNullOrEmpty
	            (Import-Csv $unattachedCsv.FullName).Count | Should -Be 1
	        }
	        finally {
	            Pop-Location
	            Remove-Item -Path $testDir -Recurse -Force
	        }
	    }

	    It 'honors AnonymizeFields and NotAnonymizeFields when anonymizing' {
	        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
	        New-Item -ItemType Directory -Path $testDir | Out-Null
	        Push-Location $testDir
	        try {
	            Mock Get-GcpProject {
	                [pscustomobject]@{ ProjectId = 'test-project-1' }
	            }

	            Mock Get-GceInstance {
	                [pscustomobject]@{
	                    Name   = 'test-vm-1'
	                    Zone   = 'projects/test/zones/us-central1-a'
	                    Disks  = @([pscustomobject]@{ Source = 'projects/test/zones/us-central1-a/disks/disk-1' })
	                    Labels = @{}
	                }
	            }

	            Mock Get-GceDisk {
	                param(
	                    [string]$Project,
	                    [string]$DiskName
	                )
	                if ($PSBoundParameters.ContainsKey('DiskName')) {
	                    # Per-disk lookup for attached disk
	                    [pscustomobject]@{
	                        Name              = $DiskName
	                        Project           = $Project
	                        Zone              = 'projects/test/zones/us-central1-a'
	                        Id                = 'disk-1-id'
	                        SizeGb            = 100
	                        DiskEncryptionKey = $null
	                        SourceImage       = $null
	                        Labels            = @{}
	                    }
	                }
	                else {
	                    # Project-wide disk listing, with one unattached disk
	                    @(
	                        [pscustomobject]@{
	                            Name              = 'unattached-disk-1'
	                            Project           = $Project
	                            Zone              = 'projects/test/zones/us-central1-a'
	                            Id                = 'udisk-1-id'
	                            SizeGb            = 50
	                            DiskEncryptionKey = $null
	                            SourceImage       = $null
	                            Users             = $null
	                            Labels            = @{}
	                        }
	                    )
	                }
	            }

	            Test-Path $scriptPath | Should -BeTrue

	            & $scriptPath -Projects 'test-project-1' -Anonymize -AnonymizeFields 'Zone' -NotAnonymizeFields 'Project'

	            $mapCsv = Get-ChildItem 'gcp_anonymized_keys_to_actual_values-*.csv' | Select-Object -First 1
	            $mapCsv | Should -Not -BeNullOrEmpty

	            $map = Import-Csv $mapCsv.FullName
	            $map.ActualValue | Should -Contain 'us-central1-a'
	            $map.ActualValue | Should -Not -Contain 'test-project-1'

	            $zip = Get-ChildItem 'gcp_sizing_results_*.zip' | Select-Object -First 1
	            $zip | Should -Not -BeNullOrEmpty

	            $extractDir = Join-Path $testDir 'unzipped'
	            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

	            $vmCsv = Get-ChildItem $extractDir -Filter 'gce_vm_info-*.csv' | Select-Object -First 1
	            $vmCsv | Should -Not -BeNullOrEmpty

	            $vmData = Import-Csv $vmCsv.FullName
	            $vmData.Count | Should -Be 1
	            $vmData[0].Project | Should -Be 'test-project-1'
	            $vmData[0].Zone    | Should -Not -Be 'us-central1-a'
	        }
	        finally {
	            Pop-Location
	            Remove-Item -Path $testDir -Recurse -Force
	        }
	    }
}

