Function Test-AzureJson {
  Param(
    [string]
    $FilePath
  )

  Context "JSON Structure" {
    
    $templateProperties = (get-content "$FilePath" -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue)

    It "should be less than 1 Mb" {
      Get-Item $FilePath | Select-Object -ExpandProperty Length | Should -BeLessOrEqual 1073741824
    }

    It "Converts from JSON" {
      $templateProperties | Should -Not -BeNullOrEmpty
    }

    It "should have a `$schema section" {
      $templateProperties."`$schema" | Should -Not -BeNullOrEmpty
    }

    It "should have a contentVersion section" {
      $templateProperties.contentVersion | Should -Not -BeNullOrEmpty
    }

    It "should have a parameters section" {
      $templateProperties.parameters | Should -Not -BeNullOrEmpty
    }

    It "should have less than 256 parameters" {
      $templateProperties.parameters.Length | Should -BeLessOrEqual 256
    }

    It "might have a variables section" {
      $result = $null -eq $templateProperties.variables

      if($result){
        $result | Should -Be $true
      }
      else {
        Set-TestInconclusive -Message "Section isn't mandatory, however it's a group practice to have it defined"
      }
    }
    
    It "must have a resources section" {
      $templateProperties.resources | Should -Not -BeNullOrEmpty
    }

    It "might have an outputs section" {
      $result = $null -eq $templateProperties.outputs

      if($result){
        $result | Should -Be $true
      }
      else {
        Set-TestInconclusive -Message "Section isn't mandatory, however it's a group practice to have it defined"
      }
    }
  }

  $jsonMainTemplate = Get-Content "$FilePath"
  $objMainTemplate = $jsonMainTemplate | ConvertFrom-Json -ErrorAction SilentlyContinue

  $parametersUsage = [System.Text.RegularExpressions.RegEx]::Matches($jsonMainTemplate, "parameters(\(\'\w*\'\))") | Select-Object -ExpandProperty Value -Unique
  Context "Referenced Parameters" {
    ForEach($parameterUsage In $parametersUsage)
    {
      $parameterUsage = $parameterUsage.SubString($parameterUsage.IndexOf("'") + 1).Replace("')","")
    
      It "should have a parameter called $parameterUsage" {
        $objMainTemplate.parameters.$parameterUsage | Should -Not -Be $null
      }
    }
  }

  $variablesUsage = [System.Text.RegularExpressions.RegEx]::Matches($jsonMainTemplate, "variables(\(\'\w*\'\))") | Select-Object -ExpandProperty Value -Unique
  Context "Referenced Variables" {
    ForEach($variableUsage In $variablesUsage)
    {
      $variableUsage = $variableUsage.SubString($variableUsage.IndexOf("'") + 1).Replace("')","")
      
      It "should have a variable called $variableUsage" {
        $objMainTemplate.variables.$variableUsage | Should -Not -Be $null
      }
    }
  }

  Context "Missing opening or closing square brackets" {
    For($i=0;$i -lt $jsonMainTemplate.Length;$i++) {
      $Matches = [System.Text.RegularExpressions.Regex]::Matches($jsonMainTemplate[$i],"\"".*\""")

      ForEach($Match In $Matches) {
        $PairCharNumber = ($Match.Value.Length - $Match.Value.Replace("[","").Replace("]","").Length) % 2

        if($PairCharNumber -ne 0) {
          Write-Host $Match.Value
          It "should have same amount of opening and closing square brackets (Line $($i + 1))" {
            $PairCharNumber | Should -Be 0
          }

          break
        }
      }
    }
  }

  Context "Missing opening or closing parenthesis" {
    For($i=0;$i -lt $jsonMainTemplate.Length;$i++) {
      $Matches = [System.Text.RegularExpressions.Regex]::Matches($jsonMainTemplate[$i],"\"".*\""")

      ForEach($Match In $Matches) {
        $PairCharNumber = ($Match.Value.Length - $Match.Value.Replace("(","").Replace(")","").Length) % 2

        if($PairCharNumber -ne 0) {
          It "should have same amount of opening and closing parenthesis (Line $($i + 1))" {
            $PairCharNumber | Should -Be 0
          }

          break
        }
      }
    }
  }

  Context "Azure API Validation" {
    $context = $null
    try {$context = Get-AzureRmContext} catch {}
    if($null -ne $context.Subscription.Id) {
      $Parameters = $objMainTemplate.parameters | Get-Member | Where-Object -Property MemberType -eq -VAlue "NoteProperty" | Select-Object -ExpandProperty Name
      $TemplateParameters = @{}
      $PesterRGCreated = $false

      ForEach($Parameter In $Parameters) {
        if(!($objMainTemplate.parameters.$Parameter.defaultValue)) {
          if($objMainTemplate.parameters.$Parameter.allowedValues) {
            $TemplateParameters.Add($Parameter, $objMainTemplate.parameters.$Parameter.allowedValues[0])
          }
          else {
            switch ($objMainTemplate.parameters.$Parameter.type) {
              "bool" {
                $TemplateParameters.Add($Parameter, $true)
              }

              "int" {
                if($objMainTemplate.parameters.$Parameter.minValue) {
                  $TemplateParameters.Add($Parameter, $objMainTemplate.parameters.$Parameter.minValue)
                }
                else {
                  $TemplateParameters.Add($Parameter, 1)
                }
              }

              "string" {
                if($objMainTemplate.parameters.$Parameter.minValue) {
                  $TemplateParameters.Add($Parameter, "a" * $objMainTemplate.parameters.$Parameter.minLength)
                }
                else {
                  $TemplateParameters.Add($Parameter, "dummystring")
                }
              }

              "securestring" {
                $TemplateParameters.Add($Parameter, "dummystring")
              }

              "array" {
                $TemplateParameters.Add($Parameter, @(1,2,3))
              }

              "object" {
                $TemplateParameters.Add($Parameter, (New-Object -TypeName psobject -Property @{"DummyProperty"="DummyValue"}))
              }

              "secureobject" {
                $TemplateParameters.Add($Parameter, (New-Object -TypeName psobject -Property @{"DummyProperty"="DummyValue"}))
              }
            }
          }
        }
      }

      if(!(Get-AzureRmResourceGroup -Name "PesterRG" -ErrorAction SilentlyContinue)) {
        New-AzureRmResourceGroup -Name "PesterRG" -Location "East US" | Out-Null
        $PesterRGCreated = $true
      }

      $output = Test-AzureRmResourceGroupDeployment -ResourceGroupName "PesterRG" -TemplateFile $armTemplate.FullName @TemplateParameters

      if($PesterRGCreated) {
        Remove-AzureRmResourceGroup -Name "PesterRG" | Out-Null
      }

      It "should be a valid template" {
        $output | Should -BeNullOrEmpty
      }

      ForEach($ValidationError In $output) {
        It ("shouldn't have {0}" -f $ValidationError.Code) {
          $ValidationError.Message | Should -BeNullOrEmpty
        }
      }
    }
    else {
      It "should be a valid template" {
        Set-TestInconclusive -Message "Not logged to AzureRM for which Test-AzureRmResourceGroupDeployment cannot be executed."
      }
    }
  }
  
  $nestedTemplates = $objMainTemplate.resources | Where-Object -Property Type -IEQ -Value "Microsoft.Resources/deployments"
  
  if($null -ne $nestedTemplates)
  {
    ForEach($nestedTemplate In $nestedTemplates)
    {
      If($null -ne $nestedTemplate.properties.templateLink.uri)
      {
        $nestedTemplateFileName = [System.Text.RegularExpressions.RegEx]::Matches($nestedTemplate.properties.templateLink.uri, "\w*\.json(\?)?").Value
        $nestedTemplateFileName = $nestedTemplateFileName.SubString($nestedTemplateFileName.IndexOf("'") + 1).Replace("'","").Replace('?','')

        Context "Nested Template: $nestedTemplateFileName" {
          It "should exist the nested template at $WorkingFolder\linked\$nestedTemplateFileName" {
            "$WorkingFolder\linked\$nestedTemplateFileName" | Should -Exist
          }

          if(Test-Path "$WorkingFolder\linked\$nestedTemplateFileName")
          {
            $nestedParameters = (Get-Content "$WorkingFolder\linked\$nestedTemplateFileName" | ConvertFrom-Json).parameters
            $requiredNestedParameters = $nestedParameters | Get-Member -MemberType NoteProperty | Where-Object -FilterScript {$null -eq $nestedParameters.$($_.Name).defaultValue} | ForEach-Object -Process {$_.Name}

            
            ForEach($requiredNestedParameter In $requiredNestedParameters)
            {
              It "should set a value for $requiredNestedParameter" {
                $nestedTemplate.properties.parameters.$requiredNestedParameter | Should -Not -BeNullOrEmpty
              }
            }
          }
        }
      }
    }
  }
}

Function Test-PowershellScript {
  Param(
    [string]$FilePath
  )

  It "is a valid Powershell Code"{
    $psFile = Get-Content -Path $FilePath -ErrorAction Stop
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
    $errors.Count | Should -Be 0
  }
}

$WorkingFolder = Split-Path -Parent $MyInvocation.MyCommand.Path

$armTemplates = Get-ChildItem -Path "$WorkingFolder" -Filter "*.json" -recurse -File | Where-Object -FilterScript {(Get-Content -Path $_.FullName -Raw) -ilike "*schema.management.azure.com/*/deploymentTemplate.json*"}
$powershellScripts = Get-ChildItem -Path "$WorkingFolder" -Filter "*.ps1" -Exclude "*.tests.*" -Recurse -File

#region ARM Template
ForEach($armTemplate In $armTemplates)
{
  Describe $armTemplate.FullName.Replace($WorkingFolder,"") {
    Test-AzureJson -FilePath $armTemplate.FullName
  }
  $jsonMainTemplate = Get-Content $armTemplate.FullName
  $objMainTemplate = $jsonMainTemplate | ConvertFrom-Json -ErrorAction SilentlyContinue
  $mainNestedTemplates = $null

  If($objMainTemplate.resources | Where-Object -Property Type -IEQ -Value "Microsoft.Resources/deployments")
  {
    $mainNestedTemplates = [System.Text.RegularExpressions.RegEx]::Matches($($objMainTemplate.resources | Where-Object -Property Type -IEQ -Value "Microsoft.Resources/deployments" | ForEach-Object -Process {$_.properties.templateLink.uri}), "\'\w*\.json\??\'") | Select-Object -ExpandProperty Value -Unique
  }

  ForEach($nestedTemplate In $mainNestedTemplates)
  {
    $nestedTemplate = $nestedTemplate.SubString($nestedTemplate.IndexOf("'") + 1).Replace("'","").Replace('?','')
    
    Describe "Nested: $WorkingFolder\linked\$nestedTemplate" {
      It "Should exist" {
        "$WorkingFolder\linked\$nestedTemplate" | Should -Exist
      }

      if(Test-Path $WorkingFolder\linked\$nestedTemplate)
      {
        Test-AzureJson -FilePath $WorkingFolder\linked\$nestedTemplate
      }
    }
  }
}
#endregion

#region Powershell Scripts
ForEach($powershellScript In $powershellScripts) {
  Describe $powershellScript.FullName.Replace($WorkingFolder,"") {
    Test-PowershellScript -FilePath $powershellScript.FullName
  }
}
#endregion