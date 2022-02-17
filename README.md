# Summary
Polls SCCM for information about all deployments and exports to a CSV.  
Intended to provide a faster way to look at deployment reporting results, versus meticulously configuring columns in the deployment monitoring section of the console GUI.  

Focuses on only application deployments, since they are the most problematic.  
Focuses on the number of computers reporting success, error, in progress, other, and unknown statuses.  
Does some calcuations to determine success percentage, both overall, and for just the percentage of machines that actually report in.  

# Org-specific warning
Note: this module is currently written specifically for use in the College of Engineering of the University of Illinois. It's published mostly for reference and requires refactoring for use in other organizations.  

# Requirements
Must be run on a computer with the SCCM console app installed, and run by a user with SCCM permissions.

# Usage
1. Download `Get-DeploymentReport.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\Get-DeploymentReport\Get-DeploymentReport.psm1`.
2. Run it.
  - e.g. `Get-DeploymentReport -Log ":ENGRIT:" -Csv ":ENGRIT:"`
3. Review the generated CSV.

# Notes
- It's recommended to filter out "Available" deployments, as only those which have been installed show up as a success.  
- It's recommended to calculate the average of the `RespondedCompliance` column and the `TargetedCompliance` column (separately).  
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
