# Run-Pester
The purpose of this script is to trigger Pester scripts as part of an Azure DevOps Pipeline (either Build or Release). It's able to search for Pester files based on a specific pattern and makes sure a particular version of Pester module is installed before invoking the script.

## Syntax
```powershell
.\Run-Pester -TestFilePattern <string> [-PesterVersion <string>] [<CommonParameters>]
```

## Parameters
Table describing each of the parameters:

| Name | Type | Mandatory | Description |
| --- | --- | --- | --- |
| TestFilePattern | String | Yes | Specifies the Filter parameter to be passed-through Get-ChildItems to find Pester files |
| PesterVersion | String | No | Specifies the specific Pester version to be installed. Default value is "latest" |

## Output
Return code of the script is the amount of failed tests. Also, each Pester script will generate an NUNIT export at $(Common.TestResultsDirectory)\TEST-[Pester-file-name].xml