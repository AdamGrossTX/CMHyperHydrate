
#https://github.com/PowerShell/CertificateDsc/issues/54
$Main = {
    ForEach ($Template in $Configs) {
        Write-Host $Template.displayName
        Create-PKICertTemplate -TemplateDisplayName $Template.DisplayName  -PKIConfig $Template.Config -SecurityConfig $Template.Security
    }
}

$Configs = @(
	@{
		"DisplayName" = "Domain Controller Authentication (KDC)"
		"Config" = [hashtable]@{
			"flags" = "131168"
			"pKIDefaultKeySpec" = "1"
			"pKIKeyUsage" = [Byte[]]( "160","0" )
			"pKIMaxIssuingDepth" = "0"
			"pKICriticalExtensions" = @( "2.5.29.15","2.5.29.17" )
			"pKIExpirationPeriod" = ([Byte[]](0,64,57,135,46,225,254,255))
			"pKIOverlapPeriod" = ([Byte[]](0,128,166,10,255,222,255,255))
			"pKIExtendedKeyUsage" = @( "1.3.6.1.5.5.7.3.2","1.3.6.1.5.5.7.3.1","1.3.6.1.4.1.311.20.2.2","1.3.6.1.5.2.3.5" )
			"msPKI-RA-Signature" = "0"
			"msPKI-Enrollment-Flag" = "32"
			"msPKI-Private-Key-Flag" = "67436544"
			"msPKI-Certificate-Name-Flag" = "138412032"
			"msPKI-Minimal-Key-Size" = "2048"
			"msPKI-Template-Schema-Version" = "4"
			"msPKI-Template-Minor-Revision" = "3"
			"msPKI-Cert-Template-OID" = "1.3.6.1.4.1.311.21.8.9297300.10481922.2378919.4036973.687234.60.15267975.11339196"
			"msPKI-Supersede-Templates" = @( "KerberosAuthentication","DomainControllerAuthentication","DomainController" )
			"msPKI-Certificate-Application-Policy" = @( "1.3.6.1.5.5.7.3.2","1.3.6.1.5.5.7.3.1","1.3.6.1.4.1.311.20.2.2","1.3.6.1.5.2.3.5" )
			"msPKI-RA-Application-Policies" = "msPKI-Asymmetric-Algorithm``PZPWSTR``RSA``msPKI-Hash-Algorithm``PZPWSTR``SHA256``msPKI-Key-Usage``DWORD``16777215``msPKI-Symmetric-Algorithm``PZPWSTR``3DES``msPKI-Symmetric-Key-Length``DWORD``168``"
	}
		"Security" = @(
			@{
				"IdentityReference" = "NT AUTHORITY\Authenticated Users"
				"ActiveDirectoryRights" = "GenericRead"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Desktop Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "a05b8cc2-17bc-4802-a710-e7c15ab866a2"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Read-only Domain Controllers"
				"ActiveDirectoryRights" = "ReadProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "a05b8cc2-17bc-4802-a710-e7c15ab866a2"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Read-only Domain Controllers"
				"ActiveDirectoryRights" = "ReadProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Controllers"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "a05b8cc2-17bc-4802-a710-e7c15ab866a2"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Controllers"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			}
		)
	}
	@{
		"DisplayName" = "ConfigMgr Web Server Certificate"
		"Config" = [hashtable]@{
			"flags" = "131649"
			"pKIDefaultKeySpec" = "1"
			"pKIKeyUsage" = [Byte[]]( "160","0" )
			"pKIMaxIssuingDepth" = "0"
			"pKICriticalExtensions" = "2.5.29.15"
			"pKIExpirationPeriod" = ([Byte[]](0,64,30,164,232,101,250,255))
			"pKIOverlapPeriod" = ([Byte[]](0,128,166,10,255,222,255,255))
			"pKIExtendedKeyUsage" = "1.3.6.1.5.5.7.3.1"
			"pKIDefaultCSPs" = @( "2,Microsoft DH SChannel Cryptographic Provider","1,Microsoft RSA SChannel Cryptographic Provider" )
			"msPKI-RA-Signature" = "0"
			"msPKI-Enrollment-Flag" = "8"
			"msPKI-Private-Key-Flag" = "16842752"
			"msPKI-Certificate-Name-Flag" = "1"
			"msPKI-Minimal-Key-Size" = "2048"
			"msPKI-Template-Schema-Version" = "2"
			"msPKI-Template-Minor-Revision" = "1"
			"msPKI-Cert-Template-OID" = "1.3.6.1.4.1.311.21.8.9297300.10481922.2378919.4036973.687234.60.11634013.16673656"
			"msPKI-Certificate-Application-Policy" = "1.3.6.1.5.5.7.3.1"
	}
		"Security" = @(
			@{
				"IdentityReference" = "NT AUTHORITY\Authenticated Users"
				"ActiveDirectoryRights" = "GenericRead"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Administrator"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\CM01$"
				"ActiveDirectoryRights" = "ReadProperty, GenericExecute"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\ConfigMgr Site Servers"
				"ActiveDirectoryRights" = "ReadProperty, GenericExecute"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\CM01$"
				"ActiveDirectoryRights" = "ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\ConfigMgr Site Servers"
				"ActiveDirectoryRights" = "ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			}
		)
	}
	@{
		"DisplayName" = "ConfigMgr Distribution Point Certificate"
		"Config" = [hashtable]@{
			"flags" = "131680"
			"pKIDefaultKeySpec" = "1"
			"pKIKeyUsage" = [Byte[]]( "160","0" )
			"pKIMaxIssuingDepth" = "0"
			"pKICriticalExtensions" = "2.5.29.15"
			"pKIExpirationPeriod" = ([Byte[]](0,192,171,149,139,163,252,255))
			"pKIOverlapPeriod" = ([Byte[]](0,128,166,10,255,222,255,255))
			"pKIExtendedKeyUsage" = "1.3.6.1.5.5.7.3.2"
			"pKIDefaultCSPs" = "1,Microsoft RSA SChannel Cryptographic Provider"
			"msPKI-RA-Signature" = "0"
			"msPKI-Enrollment-Flag" = "40"
			"msPKI-Private-Key-Flag" = "16842768"
			"msPKI-Certificate-Name-Flag" = "134217728"
			"msPKI-Minimal-Key-Size" = "2048"
			"msPKI-Template-Schema-Version" = "2"
			"msPKI-Template-Minor-Revision" = "3"
			"msPKI-Cert-Template-OID" = "1.3.6.1.4.1.311.21.8.9297300.10481922.2378919.4036973.687234.60.7762591.7797208"
			"msPKI-Certificate-Application-Policy" = "1.3.6.1.5.5.7.3.2"
	}
		"Security" = @(
			@{
				"IdentityReference" = "NT AUTHORITY\Authenticated Users"
				"ActiveDirectoryRights" = "GenericRead"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Administrator"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\CM01$"
				"ActiveDirectoryRights" = "ReadProperty, GenericExecute"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\ConfigMgr Site Servers"
				"ActiveDirectoryRights" = "ReadProperty, GenericExecute"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\CM01$"
				"ActiveDirectoryRights" = "ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\ConfigMgr Site Servers"
				"ActiveDirectoryRights" = "ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			}
		)
	}
	@{
		"DisplayName" = "ConfigMgr Client Certificate"
		"Config" = [hashtable]@{
			"flags" = "131680"
			"pKIDefaultKeySpec" = "1"
			"pKIKeyUsage" = [Byte[]]( "160","0" )
			"pKIMaxIssuingDepth" = "0"
			"pKICriticalExtensions" = "2.5.29.15"
			"pKIExpirationPeriod" = ([Byte[]](0,192,171,149,139,163,252,255))
			"pKIOverlapPeriod" = ([Byte[]](0,128,166,10,255,222,255,255))
			"pKIExtendedKeyUsage" = "1.3.6.1.5.5.7.3.2"
			"pKIDefaultCSPs" = "1,Microsoft RSA SChannel Cryptographic Provider"
			"msPKI-RA-Signature" = "0"
			"msPKI-Enrollment-Flag" = "40"
			"msPKI-Private-Key-Flag" = "16842752"
			"msPKI-Certificate-Name-Flag" = "134217728"
			"msPKI-Minimal-Key-Size" = "2048"
			"msPKI-Template-Schema-Version" = "2"
			"msPKI-Template-Minor-Revision" = "3"
			"msPKI-Cert-Template-OID" = "1.3.6.1.4.1.311.21.8.9297300.10481922.2378919.4036973.687234.60.16115542.5458281"
			"msPKI-Certificate-Application-Policy" = "1.3.6.1.5.5.7.3.2"
	}
		"Security" = @(
			@{
				"IdentityReference" = "NT AUTHORITY\Authenticated Users"
				"ActiveDirectoryRights" = "GenericRead"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Administrator"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Computers"
				"ActiveDirectoryRights" = "ReadProperty, GenericExecute"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner"
				"AccessControlType" = "Allow"
				"ObjectType" = "00000000-0000-0000-0000-000000000000"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Computers"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Domain Computers"
				"ActiveDirectoryRights" = "ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "a05b8cc2-17bc-4802-a710-e7c15ab866a2"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			},
			@{
				"IdentityReference" = "CPDesk\Enterprise Admins"
				"ActiveDirectoryRights" = "ReadProperty, WriteProperty, ExtendedRight"
				"AccessControlType" = "Allow"
				"ObjectType" = "0e10c968-78fb-11d2-90d4-00c04f79dc55"
				"InheritanceType" = "None"
				"InheritedObjectType" = "00000000-0000-0000-0000-000000000000"
			}
		)
	}
)



Function Create-PKICertTemplate {
Param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $TemplateDisplayName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [hashtable]
    $PKIConfig,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    $SecurityConfig

)
    
    $CN = $TemplateDisplayName.Replace(" ","")
    $PKIConfig.revision = "100"

    $ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext 
    $ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$($ConfigContext)" 

    $Template = [ADSI]"LDAP://CN=$($CN),CN=Certificate Templates,CN=Public Key Services,CN=Services,$($ConfigContext)"
    If([string]::IsNullOrEmpty($Template.Name)){
        # create if not exists
        $Template = $ADSI.Create("pKICertificateTemplate", "CN=$($CN)")
    }

    $Template.Put("displayName", $TemplateDisplayName)
    $Template.SetInfo()
    
    foreach($key in $PKIConfig.Keys){
        $Template.Put($key, $PKIConfig[$key])
    }

    $Template.InvokeSet("pKIKeyUsage", $PKIConfig.pKIKeyUsage)
    $Template.SetInfo()

    #ResetPerms
    $Template.ObjectSecurity.Access | ForEach-Object {$Template.ObjectSecurity.RemoveAccessRule(($_))}
    #Where-Object InheritanceFlags -ne "ContainerInherit" | 
    ForEach ($Permission in $SecurityConfig) {
        $ID = $Permission.IdentityReference.Split("\")
        $ACC = [System.Security.Principal.NTAccount]::new($ID[0], $ID[1])
        $IdentityReference = $ACC.Translate([System.Security.Principal.SecurityIdentifier])
        $Rule = [System.DirectoryServices.ActiveDirectoryAccessRule]::New($IdentityReference,$Permission.ActiveDirectoryRights,$Permission.AccessControlType,$Permission.ObjectType,$Permission.InheritanceType,$Permission.InheritedObjectType)

        $Template.ObjectSecurity.AddAccessRule($Rule)
        $Template.commitchanges()
    }


    #Allow Computers to Enroll

    #$DomainName = Get-WMIObject Win32_NTDomain | Select -ExpandProperty DomainName
    #$Template.ObjectSecurity.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])
    #$ADObj = New-Object System.Security.Principal.NTAccount("$env\Domain Controllers")
    #$Identity = $ADObj.Translate([System.Security.Principal.SecurityIdentifier])
    #$ADRights = [System.DirectoryServices.ActiveDirectoryRights]::ReadProperty -bor [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty -bor [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
    #$Type = "Allow"
    #$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
    #$Template.psbase.ObjectSecurity.SetAccessRule($ACE)
    #$Template.psbase.commitchanges()
    #$P = Start-Process "C:\Windows\System32\certtmpl.msc" -PassThru
    #Start-Sleep 2
    #$P | Stop-Process            
    ##Add-CATemplate -name "$TemplateDisplayName" -ErrorAction SilentlyContinue -Force


    #$ACC = [System.Security.Principal.NTAccount]::new($DomainName, "Domain Computers")
    #$Identity = $ACC.Translate([System.Security.Principal.SecurityIdentifier])
    #$EnrollObjectType = [Guid]::Parse("0e10c968-78fb-11d2-90d4-00c04f79dc55")
    #$ADRights = [System.DirectoryServices.ActiveDirectoryRights]::ReadProperty -bor [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty -bor [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
    #$Type = [System.Security.AccessControl.AccessControlType]::Allow
    #$Rule = [System.DirectoryServices.ActiveDirectoryAccessRule]::New($Identity, $ADRights, $Type, $EnrollObjectType)
    #$Template.ObjectSecurity.AddAccessRule($Rule)
    #$Template.commitchanges()
}

& $Main
