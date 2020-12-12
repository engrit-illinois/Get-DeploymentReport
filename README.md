Polls SCCM for information about all deployments and exports to a CSV.  
Intended to provide a faster way to look at deployment reporting results, versus meticulously configuring columns in the deployment monitoring section of the console GUI.  

Focuses on only application deployments, since they are the most problematic.  
Focuses on the number of computers reporting success, error, in progress, other, and unknown statuses.  
Does some calcuations to determine success percentage, both overall, and for just the percentage of machines that actually report in.  

Recommended to filter out "Available" deployments, as only those which have been installed show up as a success.  
Recommended to calculate the average the `RespondedCompliance` column and the `TargetedCompliance` column (separately).  

To use: download the script and run it. <ust be run on a computer with the SCCM console app installed, and run by a user with SCCM permissions.

By mseng3.