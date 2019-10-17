
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
ForEach ($SourceTemplateCN in $SourceTemplates) {
		$ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext 
		$ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
		$Template = [ADSI]"LDAP://CN=$SourceTemplateCN,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
		$PropertyList = $Template.Properties.PropertyNames | Where-Object {$_.StartsWith("pKI") -or $_.StartsWith("flags") -or $_.StartsWith("msPKI-")}

		Write-Host "	@{"
		Write-Host "		""DisplayName"" = ""$($Template.displayName.ToString()) - Test"""
		Write-Host "		""Config"" = [hashtable]@{"
			ForEach($Property in $PropertyList) {
				$Value = $Template.psbase.Properties.Item($Property).Value
				If($Property -eq "pKIExpirationPeriod" -or $Property -eq "pKIOverlapPeriod") {
					$b = $Value -join ','
					Write-Host "			""$Property"" = ([Byte[]]($b))"

				}
				ElseIf($Value -is [byte[]]) {
					$b = '"{0}"' -f ($Value -join '","')
					Write-Host "			""$Property"" = [Byte[]]("$($b.ToString())")"
				}
				ElseIf($Value -is [Object[]]) {
					$b = '"{0}"' -f ($Value -join '","')
					Write-Host "			""$Property"" = @("$($b.ToString())")"
				}
				ElseIf($Value -match '`') {
					$NewVal = $Value.Replace('`','``')
					Write-Host "			""$Property"" = ""$($NewVal.ToString())"""
				}
				Else {
					Write-Host "			""$Property"" = ""$($Value.ToString())"""
				}
			}
		Write-Host "	}"

		#GetPermissions
		$TemplateSecurityConfig = $Template.ObjectSecurity.Access | Select IdentityReference,ActiveDirectoryRights,AccessControlType,ObjectType,InheritanceType,InheritedObjectType

		Write-Host "		""Security"" = @("
		$Count = 0
		ForEach($Config in $TemplateSecurityConfig) {
			$Count++
			Write-Host "			@{"
			ForEach($Prop in $Config.PSObject.Properties) {
				$Value = $Prop.Value
				If($Prop.Name.ToString() -Match "IdentityReference" -and $Value -notmatch 'NT AUTHORITY') {
					$Value = "{0}\{1}" -f $TargetDomain,($Value.ToString().Split("\"))[1]
				}
				Write-Host "				""$($Prop.Name.ToString())"" = ""$($Value.ToString())"""
			}
			If($Count -eq $TemplateSecurityConfig.Count) {
				Write-Host "			}"
			}
			Else {
				Write-Host "			},"
			}
		}
		Write-Host "		)"
		Write-Host "	}"
}

Write-Host ")"


Stop-Transcript