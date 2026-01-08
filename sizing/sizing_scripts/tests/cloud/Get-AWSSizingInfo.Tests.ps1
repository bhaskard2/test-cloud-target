$ErrorActionPreference = 'Stop'

# Provide stub implementations for the AWS-related cmdlets used by the
# sizing script so that unit tests never talk to real AWS services. Pester
# mocks in individual tests can override these stubs where needed.

# Top-level identity / credential helpers must be mocked per-test; the
# stubs intentionally throw so that any un-mocked usage is visible.
function global:Get-STSCallerIdentity {
	throw 'Get-STSCallerIdentity stub: use Pester Mock in tests.'
}

function global:Get-AWSCredential {
	throw 'Get-AWSCredential stub: use Pester Mock in tests.'
}

# Provide a stub for the script's internal getAWSData function so that the
# script under test can call it even when the real implementation is not
# available (for example, when running in a minimal test container). Pester
# mocks in the tests then override this stub when we do not want to execute
# the real implementation.
function global:getAWSData {
	throw 'getAWSData stub: use Pester Mock in tests.'
}

# Lightweight, always-safe stubs for the remaining AWS cmdlets used inside
# getAWSData. These return synthetic data so the script logic can run without
# reaching out to real AWS services. Individual tests can still override
# behaviour with Pester Mock where needed.

function global:Get-EC2Region {
    # Return a single synthetic region object; the sizing script expands the
    # RegionName property to build its region list.
    [pscustomobject]@{ RegionName = 'us-east-1' }
}

function global:Get-IAMAccountAlias { 'TestAccountAlias' }

function global:Get-CWmetriclist { @() }

function global:Get-CWMetricStatistics {
    param(
        [string]$Namespace,
        [string]$MetricName,
        $Dimension,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [datetime]$UtcStartTime,
        [datetime]$UtcEndTime,
        [int]$Period,
        [string[]]$Statistic,
        $Region,
        $Credential,
        [string]$ErrorAction
    )

    # Provide synthetic CloudWatch statistics for FSx metrics so that the
    # sizing script can compute non-zero capacities without talking to AWS.
    $value = switch ($MetricName) {
        'StorageUsed'     { 107374182400 }  # 100 GiB in bytes
        'StorageCapacity' { 214748364800 }  # 200 GiB in bytes
        default           { 0 }
    }

    [pscustomobject]@{
        Datapoints = @(
            [pscustomobject]@{
                Maximum = $value
                Sum     = $value
            }
        )
    }
}

function global:Get-S3Bucket { @() }

function global:Get-S3BucketTagging { @() }

function global:Get-EC2Instance {
    # Return a single EC2 instance with one attached volume and a Name tag
    $volumeMapping = [pscustomobject]@{
        ebs = @(
            [pscustomobject]@{
                VolumeId = 'vol-attached-1'
            }
        )
    }

    $instance = [pscustomobject]@{
        InstanceId          = 'i-0123456789abcdef0'
        BlockDeviceMappings = $volumeMapping
        Tags                = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestInstance' }
        )
        InstanceType        = 'm5.large'
        Platform            = 'linux'
        ProductCodes        = [pscustomobject]@{ ProductCodeType = 'test' }
    }

    [pscustomobject]@{
        Instances = @($instance)
    }
}

function global:Get-EC2Volume {
    # Used both for attached volume lookups (Size only) and unattached
    # volume listing. A single synthetic volume is enough for both paths.
    [pscustomobject]@{
        VolumeId   = 'vol-0123456789abcdef0'
        Size       = 100
        Tags       = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestVolume' }
        )
        VolumeType = 'gp3'
    }
}

function global:Get-RDSDBInstance {
    # One RDS instance with 20 GiB allocated storage
    [pscustomobject]@{
        DBName                 = 'testdb'
        DBInstanceIdentifier   = 'testdb-instance-1'
        AllocatedStorage       = 20
        DBInstanceClass        = 'db.m5.large'
        Engine                 = 'postgres'
        EngineVersion          = '13.7'
        DBInstanceStatus       = 'available'
        BackupRetentionPeriod  = 7
        PreferredBackupWindow  = '00:00-01:00'
        StorageType            = 'gp2'
        TagList                = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestRDS' }
        )
    }
}

function global:Get-EFSFileSystem {
    # Single EFS file system with ~100 GiB logical size
    [pscustomobject]@{
        FileSystemId         = 'fs-12345678'
        FileSystemProtection = [pscustomobject]@{
            ReplicationOverwriteProtection = [pscustomobject]@{ Value = 'ENABLED' }
        }
        Name                 = 'TestEFS'
        SizeInBytes          = [pscustomobject]@{ Value = 107374182400 } # 100 GiB
        NumberOfMountTargets = 1
        OwnerId              = '123456789012'
        PerformanceMode      = 'generalPurpose'
        ProvisionedThroughputInMibps = 0
        DBInstanceIdentifier = $null
        Region               = 'us-east-1'
        ThroughputMode       = 'bursting'
        Tags                 = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestEFS' }
        )
    }
}

function global:Get-EKSClusterList { @() }

function global:Get-EKSCluster { @() }

function global:Get-EKSNodegroupList { @() }

function global:Get-EKSNodegroup { @() }

function global:Get-FSXFileSystem {
    param(
        $Credential,
        [string]$Region,
        [string]$FileSystemId,
        [string]$ErrorAction
    )

    # Single synthetic ONTAP FSx file system with 2,000 GiB capacity.
    [pscustomobject]@{
        FileSystemId          = 'fs-ontap-1'
        DNSName               = 'fs-ontap-1.fsx.us-east-1.amazonaws.com'
        FileSystemType        = [pscustomobject]@{ Value = 'ONTAP' }
        FileSystemTypeVersion = '1.0'
        OwnerId               = '123456789012'
        StorageType           = 'SSD'
        OntapConfiguration    = [pscustomobject]@{}
        WindowsConfiguration  = $null
        LustreConfiguration   = $null
        OpenZFSConfiguration  = $null
        StorageCapacity       = 2000
        Tags                  = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestFSx' }
        )
    }
}

function global:Get-FSXVolume {
    param(
        $Credential,
        [string]$Region,
        [string]$ErrorAction
    )

    # Single synthetic FSx volume on the above file system.
    [pscustomobject]@{
        FileSystemId = 'fs-ontap-1'
        VolumeId     = 'fsvol-1'
        Name         = 'TestFSxVolume'
        VolumeType   = 'ONTAP'
        LifeCycle    = 'AVAILABLE'
        Tags         = @(
            [pscustomobject]@{ Key = 'Name'; Value = 'TestFSxVolume' }
        )
    }
}

function global:Get-KMSKeyList {
    # Represent three KMS keys in the region
    @('key-1', 'key-2', 'key-3')
}

function global:Get-SECSecretList {
    # Two Secrets Manager secrets
    @('secret-1', 'secret-2')
}

function global:Get-SQSQueue {
    # Two SQS queues
    @('https://sqs.us-east-1.amazonaws.com/123456789012/queue1',
      'https://sqs.us-east-1.amazonaws.com/123456789012/queue2')
}

function global:Get-DDBTableList {
    # Single DynamoDB table name
    @('TestTable')
}

function global:Get-DDBTable {
    # Synthetic DynamoDB table metadata; the -TableName argument is ignored
    [pscustomobject]@{
        TableName        = 'TestTable'
        TableId          = '12345'
        TableArn         = 'arn:aws:dynamodb:us-east-1:123456789012:table/TestTable'
        TableSizeBytes   = 10MB
        TableStatus      = [pscustomobject]@{ Value = 'ACTIVE' }
        ItemCount        = 1000
        DeletionProtectionEnabled = $false
        GlobalTableVersion        = '2019.11.21'
        ProvisionedThroughput     = [pscustomobject]@{
            LastDecreaseDateTime     = (Get-Date).AddDays(-1)
            LastIncreaseDateTime     = (Get-Date).AddDays(-2)
            NumberOfDecreasesToday   = 0
            ReadCapacityUnits        = 5
            WriteCapacityUnits       = 5
        }
    }
}

function global:Get-BAKBackupPlanList { @() }

function global:Get-BAKBackupPlan { @() }

function global:Get-BAKBackupVault { @() }

function global:Get-BAKProtectedResourceList { @() }

function global:Get-BAKRecoveryPoint { @() }

function global:Get-BAKBackupSelectionList { @() }

function global:Get-BAKBackupSelection { @() }

function global:Get-ORGAccountList { @() }

function global:Get-SSOAccountList { @() }

function global:Get-SSORoleCredential { @() }

# Synthetic Cost Explorer implementation used by tests that exercise the
# AWS Backup cost path. It fabricates a single ResultsByTime entry with a
# non-zero NetUnblendedCost so that the script computes a total and writes
# a backup cost CSV.
function global:Get-CECostAndUsage {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable] $TimePeriod,
		[Parameter(Mandatory = $true)]
		[string] $Granularity,
		[Parameter(Mandatory = $true)]
		[string[]] $Metrics,
		[Parameter(Mandatory = $true)]
		[hashtable] $Filter,
		$Credential,
		[string] $Region
	)

	$totals = @{}
	foreach ($metric in $Metrics) {
		$amount = if ($metric -eq 'NetUnblendedCost') { 123.45 } else { 0 }
		$totals[$metric] = [pscustomobject]@{ Amount = $amount }
	}

	[pscustomobject]@{
		ResultsByTime = @(
			[pscustomobject]@{
				TimePeriod = @{
					Start = $TimePeriod.Start
					End   = $TimePeriod.End
				}
				Total = $totals
			}
		)
	}
}

Describe 'Get-AWSSizingInfo.ps1' {
    BeforeAll {
        # Resolve script path assuming tests are run from the script directory
        # (sizing/sizing_scripts/cloud on host, /sizing_tests in the Docker image).
        $script:scriptPath = Join-Path (Get-Location) 'Get-AWSSizingInfo.ps1'

        if (-not (Test-Path $script:scriptPath)) {
            throw "Get-AWSSizingInfo.ps1 not found in current directory '$((Get-Location).Path)'. Run tests from the sizing/sizing_scripts/cloud directory."
        }
    }

    It 'creates expected CSVs and ZIP for DefaultProfile with AWS calls mocked out' {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testDir | Out-Null
        Push-Location $testDir
        try {
            # Mock AWS credential discovery so no real AWS calls are made
            Mock Get-STSCallerIdentity {
                [pscustomobject]@{
                    arn = 'arn:aws:sts::123456789012:assumed-role/Test/Session'
                }
            }

            Mock Get-AWSCredential {
                # Shape is irrelevant for this test; it is only passed through
                [pscustomobject]@{}
            }

            # Prevent any real AWS data collection; the real getAWSData
            # implementation in the script will exercise the logic against the
            # synthetic stubbed AWS cmdlets defined at the top of this file.

            # Sanity check that the script path exists before invoking
            Test-Path $scriptPath | Should -BeTrue

            # Invoke the script using the DefaultProfile parameter set. The
            # sizing script writes errors in its own top-level catch block;
            # we do not want the test's ErrorActionPreference = 'Stop' to
            # turn those into terminating exceptions. Temporarily relax the
            # preference for the duration of the script invocation.
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & $scriptPath -DefaultProfile
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            # Verify that a ZIP with the expected naming pattern was created
            $zip = Get-ChildItem 'aws_sizing_results_*.zip' | Select-Object -First 1
            $zip | Should -Not -BeNullOrEmpty

            # Extract the archive and validate all expected CSV files and their contents
            $extractDir = Join-Path $testDir 'unzipped'
            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

            $ec2Csv           = Get-ChildItem $extractDir -Filter 'aws_ec2_instance_info-*.csv'           | Select-Object -First 1
            $ec2UnattachedCsv = Get-ChildItem $extractDir -Filter 'aws_ec2_unattached_volume_info-*.csv' | Select-Object -First 1
            $rdsCsv           = Get-ChildItem $extractDir -Filter 'aws_rds_info-*.csv'                    | Select-Object -First 1
            $s3Csv            = Get-ChildItem $extractDir -Filter 'aws_s3_info-*.csv'                     | Select-Object -First 1
            $efsCsv           = Get-ChildItem $extractDir -Filter 'aws_efs_info-*.csv'                    | Select-Object -First 1
            $fsxFsCsv         = Get-ChildItem $extractDir -Filter 'aws_fsx_filesystem_info-*.csv'        | Select-Object -First 1
            $fsxVolCsv        = Get-ChildItem $extractDir -Filter 'aws_fsx_volume_info-*.csv'            | Select-Object -First 1
            $ddbCsv           = Get-ChildItem $extractDir -Filter 'aws_DynamoDB_info-*.csv'              | Select-Object -First 1
            $kmsCsv           = Get-ChildItem $extractDir -Filter 'aws_kms_numbers-*.csv'                | Select-Object -First 1
            $secretsCsv       = Get-ChildItem $extractDir -Filter 'aws_secrets_numbers-*.csv'            | Select-Object -First 1
            $sqsCsv           = Get-ChildItem $extractDir -Filter 'aws_sqs_numbers-*.csv'                | Select-Object -First 1
            $eksClustersCsv   = Get-ChildItem $extractDir -Filter 'aws_eks_clusters_info-*.csv'          | Select-Object -First 1
            $eksNodegroupsCsv = Get-ChildItem $extractDir -Filter 'aws_eks_nodegroups_info-*.csv'        | Select-Object -First 1
            $backupCostsCsv   = Get-ChildItem $extractDir -Filter 'aws_backup_costs-*.csv'               | Select-Object -First 1

            $ec2Csv           | Should -Not -BeNullOrEmpty
            $ec2UnattachedCsv | Should -Not -BeNullOrEmpty
            $rdsCsv           | Should -Not -BeNullOrEmpty
            $s3Csv            | Should -Not -BeNullOrEmpty
            $efsCsv           | Should -Not -BeNullOrEmpty
            $fsxFsCsv         | Should -Not -BeNullOrEmpty
            $fsxVolCsv        | Should -Not -BeNullOrEmpty
            $ddbCsv           | Should -Not -BeNullOrEmpty
            $kmsCsv           | Should -Not -BeNullOrEmpty
            $secretsCsv       | Should -Not -BeNullOrEmpty
            $sqsCsv           | Should -Not -BeNullOrEmpty
            $eksClustersCsv   | Should -Not -BeNullOrEmpty
            $eksNodegroupsCsv | Should -Not -BeNullOrEmpty
            $backupCostsCsv   | Should -Not -BeNullOrEmpty

            # EC2 instances CSV
            $ec2Rows = Import-Csv $ec2Csv.FullName
            $ec2Rows.Count | Should -Be 1
            $ec2Row = $ec2Rows[0]
            $ec2Row.InstanceId | Should -Be 'i-0123456789abcdef0'
            $ec2Row.Name       | Should -Be 'TestInstance'
            [int]$ec2Row.Volumes | Should -Be 1
            [int]$ec2Row.SizeGiB | Should -Be 100
            $ec2Row.Region     | Should -Be 'us-east-1'

            # EC2 unattached volumes CSV
            $ec2UnattachedRows = Import-Csv $ec2UnattachedCsv.FullName
            $ec2UnattachedRows.Count | Should -Be 1
            $ec2UnattachedRow = $ec2UnattachedRows[0]
            $ec2UnattachedRow.VolumeId | Should -Be 'vol-0123456789abcdef0'
            [int]$ec2UnattachedRow.SizeGiB | Should -Be 100
            $ec2UnattachedRow.Region | Should -Be 'us-east-1'

            # RDS CSV
            $rdsRows = Import-Csv $rdsCsv.FullName
            $rdsRows.Count | Should -Be 1
            $rdsRow = $rdsRows[0]
            $rdsRow.DBInstanceIdentifier | Should -Be 'testdb-instance-1'
            [int]$rdsRow.SizeGiB        | Should -Be 20
            $rdsRow.Region              | Should -Be 'us-east-1'
            $rdsRow.Engine              | Should -Be 'postgres'

            # EFS CSV
            $efsRows = Import-Csv $efsCsv.FullName
            $efsRows.Count | Should -Be 1
            $efsRow = $efsRows[0]
            $efsRow.FileSystemId | Should -Be 'fs-12345678'
            $efsRow.Name         | Should -Be 'TestEFS'
            [int]$efsRow.NumberOfMountTargets | Should -Be 1
            $efsRow.Region       | Should -Be 'us-east-1'

	            # FSx file systems CSV
	            $fsxFsRows = Import-Csv $fsxFsCsv.FullName
	            $fsxFsRows.Count | Should -Be 1
	            $fsxFsRow = $fsxFsRows[0]
	            $fsxFsRow.FileSystemId | Should -Be 'fs-ontap-1'
	            [int]$fsxFsRow.StorageCapacityGiB | Should -Be 2000
	            [int]$fsxFsRow.StorageUsedGiB     | Should -Be 100
	            $fsxFsRow.Region       | Should -Be 'us-east-1'

	            # FSx volumes CSV
	            $fsxVolRows = Import-Csv $fsxVolCsv.FullName
	            $fsxVolRows.Count | Should -Be 1
	            $fsxVolRow = $fsxVolRows[0]
	            $fsxVolRow.FileSystemId | Should -Be 'fs-ontap-1'
	            $fsxVolRow.VolumeId     | Should -Be 'fsvol-1'
	            [int]$fsxVolRow.StorageUsedGiB     | Should -Be 100
	            [int]$fsxVolRow.StorageCapacityGiB | Should -Be 200
	            $fsxVolRow.Region       | Should -Be 'us-east-1'

            # DynamoDB CSV
            $ddbRows = Import-Csv $ddbCsv.FullName
            $ddbRows.Count | Should -Be 1
            $ddbRow = $ddbRows[0]
            $ddbRow.TableName  | Should -Be 'TestTable'
            [int]$ddbRow.ItemCount | Should -Be 1000
            [int]$ddbRow.ProvisionedThroughputReadCapacityUnits  | Should -Be 5
            [int]$ddbRow.ProvisionedThroughputWriteCapacityUnits | Should -Be 5
            $ddbRow.Region | Should -Be 'us-east-1'

            # KMS, Secrets, and SQS CSVs
            $kmsRows = Import-Csv $kmsCsv.FullName
            $kmsRows.Count | Should -Be 1
            [int]$kmsRows[0].Keys | Should -Be 3
            $kmsRows[0].Region    | Should -Be 'us-east-1'

            $secretsRows = Import-Csv $secretsCsv.FullName
            $secretsRows.Count | Should -Be 1
            [int]$secretsRows[0].Secrets | Should -Be 2
            $secretsRows[0].Region       | Should -Be 'us-east-1'

            $sqsRows = Import-Csv $sqsCsv.FullName
            $sqsRows.Count | Should -Be 1
            [int]$sqsRows[0].Queues | Should -Be 2
            $sqsRows[0].Region      | Should -Be 'us-east-1'

	            # CSVs that are expected to be empty with the current test stubs
	            (Import-Csv $s3Csv.FullName).Count          | Should -Be 0
	            (Import-Csv $eksClustersCsv.FullName).Count | Should -Be 0
	            (Import-Csv $eksNodegroupsCsv.FullName).Count | Should -Be 0
        }
        finally {
            Pop-Location
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

		    It 'creates AWS Backup cost CSV and reports net unblended cost when Cost Explorer returns data' {
	        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
	        New-Item -ItemType Directory -Path $testDir | Out-Null
	        Push-Location $testDir
	        try {
	            # Mock identity / credential helpers so no real AWS calls are made
	            Mock Get-STSCallerIdentity {
	                [pscustomobject]@{
	                    arn = 'arn:aws:sts::123456789012:assumed-role/Test/Session'
	                }
	            }

	            Mock Get-AWSCredential {
	                [pscustomobject]@{}
	            }

	            # Use the real getAWSData implementation from the script so that the
	            # backup cost path (Get-CECostAndUsage stub above) is exercised. All
	            # other AWS calls made inside getAWSData are satisfied by the safe
	            # stub functions defined at the top of this file.

	            Test-Path $scriptPath | Should -BeTrue

	            $previousErrorActionPreference = $ErrorActionPreference
	            $ErrorActionPreference = 'Continue'
	            try {
	                # Specify a region to avoid the script needing Get-EC2Region; the
	                # Get-CECostAndUsage stub will fabricate cost data for this region.
	                $output = & $scriptPath -DefaultProfile -Regions 'us-east-1' *>&1
	            }
	            finally {
	                $ErrorActionPreference = $previousErrorActionPreference
	            }

	            $zip = Get-ChildItem 'aws_sizing_results_*.zip' | Select-Object -First 1
	            $zip | Should -Not -BeNullOrEmpty

	            $extractDir = Join-Path $testDir 'unzipped'
	            Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force

	            # Verify that the AWS Backup costs CSV was created and contains the
	            # NetUnblendedCost value from the Get-CECostAndUsage stub.
	            $backupCsv = Get-ChildItem $extractDir -Filter 'aws_backup_costs-*.csv' | Select-Object -First 1
	            $backupCsv | Should -Not -BeNullOrEmpty

	            $backupRows = Import-Csv $backupCsv.FullName
	            $backupRows | Should -Not -BeNullOrEmpty
	            $backupRows[0].AWSBackupNetUnblendedCost | Should -Be '$123.45'

	            # Optionally also assert that the summary line was written to output
	            ($output | Out-String) | Should -Match 'Net unblended cost of AWS Backup for past 12 months \+ this month so far: \$123\.45'
	        }
		        finally {
		            Pop-Location
		            Remove-Item -Path $testDir -Recurse -Force
		        }
		    }
		}
