
$TargetDomain = "ASD"

#Need to add logic to manage which servers or groups need perms
$SourceTemplates = @(
	"DomainControllerAuthentication(KDC)",
	"ConfigMgrWebServerCertificate",
	"ConfigMgrDistributionPointCertificate",
	"ConfigMgrClientCertificate"
)
Start-Transcript .\settings.txt -Force 
Write-Host ""`$Configs" = @("
foreach ($SourceTemplateCN in $SourceTemplates) {
		$ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext 
		$ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
		$Template = [ADSI]"LDAP://CN=$SourceTemplateCN,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
		$PropertyList = $Template.Properties.PropertyNames | Where-Object {$_.StartsWith("pKI") -or $_.StartsWith("flags") -or $_.StartsWith("msPKI-")}

		Write-Host "	@{"
		Write-Host "		""DisplayName"" = ""$($Template.displayName.ToString()) - Test"""
		Write-Host "		""Config"" = [hashtable]@{"
			foreach ($Property in $PropertyList) {
				$Value = $Template.psbase.Properties.Item($Property).Value
				if ($Property -eq "pKIExpirationPeriod" -or $Property -eq "pKIOverlapPeriod") {
					$b = $Value -join ','
					Write-Host "			""$Property"" = ([Byte[]]($b))"

				}
				elseif ($Value -is [byte[]]) {
					$b = '"{0}"' -f ($Value -join '","')
					Write-Host "			""$Property"" = [Byte[]]("$($b.ToString())")"
				}
				elseif ($Value -is [Object[]]) {
					$b = '"{0}"' -f ($Value -join '","')
					Write-Host "			""$Property"" = @("$($b.ToString())")"
				}
				elseif ($Value -match '`') {
					$NewVal = $Value.Replace('`','``')
					Write-Host "			""$Property"" = ""$($NewVal.ToString())"""
				}
				else {
					Write-Host "			""$Property"" = ""$($Value.ToString())"""
				}
			}
		Write-Host "	}"

		#GetPermissions
		$TemplateSecurityConfig = $Template.ObjectSecurity.Access | Select IdentityReference,ActiveDirectoryRights,AccessControlType,ObjectType,InheritanceType,InheritedObjectType

		Write-Host "		""Security"" = @("
		$Count = 0
		foreach ($Config in $TemplateSecurityConfig) {
			$Count++
			Write-Host "			@{"
			foreach ($Prop in $Config.PSObject.Properties) {
				$Value = $Prop.Value
				if ($Prop.Name.ToString() -Match "IdentityReference" -and $Value -notmatch 'NT AUTHORITY') {
					$Value = "{0}\{1}" -f $TargetDomain,($Value.ToString().Split("\"))[1]
				}
				Write-Host "				""$($Prop.Name.ToString())"" = ""$($Value.ToString())"""
			}
			if ($Count -eq $TemplateSecurityConfig.Count) {
				Write-Host "			}"
			}
			else {
				Write-Host "			},"
			}
		}
		Write-Host "		)"
		Write-Host "	}"
}

Write-Host ")"


Stop-Transcript