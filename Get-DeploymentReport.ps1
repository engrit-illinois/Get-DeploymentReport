# Documentation home: https://github.com/engrit-illinois/Get-DeploymentReport
# By mseng3

function Prep-SCCM {
	$SiteCode = "MP0" # Site code 
	$ProviderMachineName = "sccmcas.ad.uillinois.edu" # SMS Provider machine name

	# Customizations
	$initParams = @{}
	#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
	#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

	# Import the ConfigurationManager.psd1 module 
	if((Get-Module ConfigurationManager) -eq $null) {
		Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams -Scope Global
	}

	# Connect to the site's drive if it is not already present
	if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
		New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
	}

	# Set the current location to be the site code.
	Set-Location "$($SiteCode):\" @initParams
}

Prep-SCCM

# Get all deployments for applications
$deps = Get-CMDeployment | Where { $_.FeatureType -eq "1" }
# This appears to be exactly equivalent to:
#$deps = Get-CMApplicationDeployment -Summary

# For some dumb reason deployment objects don't store whether the deployment is available or required
# We have to get that from the full application deployment object
foreach($dep in $deps) {
	$appdep = Get-CMApplicationDeployment -DeploymentID $dep.DeploymentId
	$purpose = $appdep.OfferTypeID
	if($purpose -eq 0) {
		$purpose = "Required"
	}
	elseif($purpose -eq 2) {
		$purpose = "Available"
	}
	else {
		#$purpose = $purpose
	}
	
	$dep | Add-Member -NotePropertyName "_Purpose" -NotePropertyValue $purpose
}

# Select the relevant data and generate some convenient calculations
$deps = $deps | Select `
	ApplicationName,
	CollectionName,
	_Purpose,
	SummarizationTime,
	NumberTargeted,
	NumberSuccess,
	NumberInProgress,
	NumberErrors,
	NumberOther,
	NumberUnknown,
	@{
		Label = "NumberResponded"
		Expression = {
			$responded = $_.NumberSuccess +
				$_.NumberInProgress +
				$_.NumberErrors +
				$_.NumberOther +
				$_.NumberUnknown
			$responded
		}
	},
	@{
		Label = "PercentResponded"
		Expression = {
			$responded = $_.NumberSuccess +
				$_.NumberInProgress +
				$_.NumberErrors +
				$_.NumberOther +
				$_.NumberUnknown
			$targeted = $_.NumberTargeted
			if($targeted -gt 0) { [math]::Round($responded / $targeted, 2) * 100 }
			else { $result = 0 }
			$result
		}
	},
	@{
		Label = "RespondedCompliance"
		Expression = {
			$responded = $_.NumberSuccess +
				$_.NumberInProgress +
				$_.NumberErrors +
				$_.NumberOther +
				$_.NumberUnknown
			$compliant = $_.NumberSuccess
			if($responded -gt 0) { $result = [math]::Round($compliant / $responded, 2) * 100 }
			else { $result = 0 }
			$result
		}
	},
	@{
		Label = "TargetedCompliance"
		Expression = {
			$targeted = $_.NumberTargeted
			$compliant = $_.NumberSuccess
			if($targeted -gt 0) { $result = [math]::Round($compliant / $targeted, 2) * 100 }
			else { $result = 0 }
			$result
		}
	}

# Export CSV
$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$deps | Export-Csv -Encoding ascii -NoTypeInformation -Path "c:\engrit\logs\Get-DeploymentReport_$ts.csv"

# Sort data in a way that makes sense
#$deps = $deps | Sort NumberTargeted,NumberSuccess

# Format table in a way that makes sense
#$dep = $deps | Format-Table *