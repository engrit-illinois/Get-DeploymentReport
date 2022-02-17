# Documentation home: https://github.com/engrit-illinois/Get-DeploymentReport
# By mseng3

function Get-DeploymentReport {
	
	param(
		# ":ENGRIT:" will be replaced with "c:\engrit\logs\$($MODULE_NAME)_:TS:.csv"
		# ":TS:" will be replaced with start timestamp
		[string]$Csv,
		
		# ":ENGRIT:" will be replaced with "c:\engrit\logs\$($MODULE_NAME)_:TS:.log"
		# ":TS:" will be replaced with start timestamp
		[string]$Log,
		
		[switch]$NoConsoleOutput,
		[string]$Indent = "    ",
		[string]$LogFileTimestampFormat = "yyyy-MM-dd_HH-mm-ss",
		[string]$LogLineTimestampFormat = "[HH:mm:ss] ",
		[int]$Verbosity = 0
	)

	# Logic to determine final filename
	$MODULE_NAME = "Get-DeploymentReport"
	$ENGRIT_LOG_DIR = "c:\engrit\logs"
	$ENGRIT_LOG_FILENAME = "$($MODULE_NAME)_:TS:"
	$START_TIMESTAMP = Get-Date -Format $LogFileTimestampFormat

	if($Log) {
		$Log = $Log.Replace(":ENGRIT:","$($ENGRIT_LOG_DIR)\$($ENGRIT_LOG_FILENAME).log")
		$Log = $Log.Replace(":TS:",$START_TIMESTAMP)
	}
	if($Csv) {
		$Csv = $Csv.Replace(":ENGRIT:","$($ENGRIT_LOG_DIR)\$($ENGRIT_LOG_FILENAME).csv")
		$Csv = $Csv.Replace(":TS:",$START_TIMESTAMP)
	}

	function log {
		param (
			[Parameter(Position=0)]
			[string]$Msg = "",

			[int]$L = 0, # level of indentation
			[int]$V = 0, # verbosity level

			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$FC = (get-host).ui.rawui.ForegroundColor, # foreground color
			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$BC = (get-host).ui.rawui.BackgroundColor, # background color

			[switch]$E, # error
			[switch]$NoTS, # omit timestamp
			[switch]$NoNL, # omit newline after output
			[switch]$NoConsole, # skip outputting to console
			[switch]$NoLog # skip logging to file
		)

		if($E) { $FC = "Red" }

		# Custom indent per message, good for making output much more readable
		for($i = 0; $i -lt $L; $i += 1) {
			$Msg = "$Indent$Msg"
		}

		# Add timestamp to each message
		# $NoTS parameter useful for making things like tables look cleaner
		if(!$NoTS) {
			if($LogLineTimestampFormat) {
				$ts = Get-Date -Format $LogLineTimestampFormat
			}
			$Msg = "$ts$Msg"
		}

		# Each message can be given a custom verbosity ($V), and so can be displayed or ignored depending on $Verbosity
		# Check if this particular message is too verbose for the given $Verbosity level
		if($V -le $Verbosity) {

			# Check if this particular message is supposed to be logged
			if(!$NoLog) {

				# Check if we're allowing logging
				if($Log) {

					# Check that the logfile already exists, and if not, then create it (and the full directory path that should contain it)
					if(-not (Test-Path -PathType "Leaf" -Path $Log)) {
						New-Item -ItemType "File" -Force -Path $Log | Out-Null
						log "Logging to `"$Log`"."
					}

					if($NoNL) {
						$Msg | Out-File $Log -Append -NoNewline
					}
					else {
						$Msg | Out-File $Log -Append
					}
				}
			}

			# Check if this particular message is supposed to be output to console
			if(!$NoConsole) {

				# Check if we're allowing console output
				if(!$NoConsoleOutput) {

					if($NoNL) {
						Write-Host $Msg -NoNewline -ForegroundColor $FC -BackgroundColor $BC
					}
					else {
						Write-Host $Msg -ForegroundColor $FC -BackgroundColor $BC
					}
				}
			}
		}
	}
	
	function Prep-SCCM {
		log "Prepping MECM connection..."
		
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
	
	function Get-PurposeTranslation($purpose) {
		$translation = "unknown"
		if($purpose -eq 0) {
			$translation = "Required"
		}
		elseif($purpose -eq 2) {
			$translation = "Available"
		}
		else {
			$translation = "unrecogized"
		}
		$translation
	}
	
	# Get all deployments for applications
	function Get-Deps {
		log "Getting deployment data..."
		
		$deps = Get-CMDeployment | Where { $_.FeatureType -eq "1" }
		# This appears to be exactly equivalent to:
		#$deps = Get-CMApplicationDeployment -Summary

		# For some dumb reason deployment objects don't store whether the deployment is available or required
		# We have to get that from the full application deployment object
		foreach($dep in $deps) {
			$depObject = Get-CMApplicationDeployment -DeploymentID $dep.DeploymentId
			$depPurpose = $depObject.OfferTypeID
			$depSupersedence = $depObject.UpdateSupersedence
			$depObject = $null # To release memory
			
			$depPurposeString = Get-PurposeTranslation $depPurpose
			$dep | Add-Member -NotePropertyName "_Purpose" -NotePropertyValue $depPurposeString
			$dep | Add-Member -NotePropertyName "_DepSupersedence" -NotePropertyValue $depSupersedence
			
			$app = Get-CMApplication -Fast -Name $dep.ApplicationName
			$appSuperseding = $app.IsSuperseding
			$appSuperseded = $app.IsSuperseded
			$app = $null # To release memory
			
			$dep | Add-Member -NotePropertyName "_AppIsSuperseding" -NotePropertyValue $appSuperseding
			$dep | Add-Member -NotePropertyName "_AppIsSuperseded" -NotePropertyValue $appSuperseded
		}
		
		$deps
	}
	
	# Select the relevant data and generate some convenient calculations
	function Munge-Deps($deps) {
		log "Formatting data for export..."
		
		$deps | Select `
			ApplicationName,
			_AppIsSuperseding,
			_AppIsSuperseded,
			CollectionName,
			_Purpose,
			_DepSupersedence,
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
	}
	
	# Export CSV
	function Export-Deps($deps) {
		log "Exporting data to `"$Csv`"..."
		$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
		$deps | Export-Csv -Encoding ascii -NoTypeInformation -Path "c:\engrit\logs\Get-DeploymentReport_$ts.csv"
	}
	
	function Do-Stuff {
		$myPwd = $pwd.path
		Prep-SCCM
		$deps = Get-Deps
		Set-Location $myPwd
		
		$deps = Munge-Deps $deps
		Export-Deps $deps
	}
	
	Do-Stuff
	
	log "EOF"
}