Param(
  [Parameter(Mandatory)]
  [string]$TestFilePattern,
  [string]$PesterVersion = "latest"
)

If(!(Test-Path -Path $TestFilePattern)){
  Throw ("File '{0}' not found" -f $TestFilePattern)
}

"FilePath is now = $TestFilePattern"
"PesterVersion is now = $PesterVersion"

$TestOutput = $Env:Common_TestResultsDirectory
"TestOutput is now = $TestOutput"

if($PesterVersion -eq "latest") {
  "Find Pester latest version"
  $Pester = Find-Module -Name Pester

  "Latest version is '{0}'" -f $Pester.Version
}

$Module = Get-Module -Name "Pester" -ListAvailable | Select-Object -First 1
"Pester version found is = '{0}'" -f $Module.Version

If($Module.Version -ne $PesterVersion) {
  "Installing Pester..."
  Install-Module -Name "Pester" -Scope CurrentUser -AllowClobber -Force -SkipPublisherCheck
}

"Looking for Test Files..."
If($TestFilePattern.Contains('*')){
  $TestFiles = Get-ChildItem -Filter $TestFilePattern -Recurse -File
}
else {
  $TestFiles = Get-ChildItem -Filter $TestFilePattern -File
}

"Test File found: {0}" -f $TestFiles.Length

$Return = 0

ForEach($TestFile In $TestFiles){
  "Preparing to execute: {0}" -f $TestFile.FullName
  $OutputFile = "TEST-{0}.xml" -f $TestFile.Name.SubString(0,$TestFile.Name.LastIndexOf('.'))
  "OutputFile is now = $OutputFile"

  "Running Pester..."
  $Return = $Return + (Invoke-Pester -Script @{Path = $TestFile.FullName} -EnableExit -OutputFile "$TestOutput\$OutputFile" -OutputFormat NUnitXml)
}

"Pester exited with code = $Return"
$Host.SetShouldExit($Return)
Exit