function Get-GraphRoleAssignments {

	$appRoleAssignments = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ExpandProperty AppRoleAssignedTo -All
	$appRoles = $appRoleAssignments.AppRoles

	# Group by PrincipalId
	$groupedAssignments = $appRoleAssignments.AppRoleAssignedTo | Group-Object -Property PrincipalId

	$permissionMapper = Get-Content .\graph_api_permissions_map.json | ConvertFrom-Json
	$roleAssignments = @()

	foreach ($group in $groupedAssignments) {
		$principalId = $group.Name
		$firstAssignment = $group.Group | Select-Object -First 1


		# Collect all permissions for this principal
		$permissions = $group.Group | ForEach-Object {
			$currentAppRoleId = $_.AppRoleId
			$friendlyName = $appRoles | Where-Object { $_.Id -eq $currentAppRoleId } | Select-Object DisplayName, Description, Origin, Value
			[PSCustomObject]@{
				AppRoleId = $currentAppRoleId
				FriendlyName = $friendlyName.DisplayName
				Description = $friendlyName.Description
				Origin = $friendlyName.Origin
				Value = $friendlyName.Value
				Id = $_.Id
			}
		}

		# Create a consolidated object for this principal
		$roleAssignment = [PSCustomObject]@{
			PrincipalDisplayName = $firstAssignment.PrincipalDisplayName
			PrincipalType = $firstAssignment.PrincipalType
			PrincipalId = $principalId
			Permissions = $permissions
			urlPaths = foreach ($permission in $permissions) {
				$permissionMapper | Where-Object {
					($_.Application_Least -contains $permission.Value) -or
					($_.DelegatedWork_Least -contains $permission.Value)
				} | Select-Object path, full_example_url, method, version | Sort-Object path -Unique
			}
		}
		$roleAssignments += $roleAssignment
	}
	return $roleAssignments
}
Measure-Command -Expression {
	Get-GraphRoleAssignments
}


function Get-GraphRoleAssignments {

	$appRoleAssignments = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ExpandProperty AppRoleAssignedTo -All
	$appRoles = $appRoleAssignments.AppRoles

	# Preprocess app roles into a hashtable for faster lookups
	$appRolesLookup = @{}
	foreach ($appRole in $appRoles) {
		$appRolesLookup[$appRole.Id] = $appRole
	}

	# Preprocess graph_api_permissions_friendly_names.json into a hashtable for AppRoleId lookups
	$friendlyNames = Get-Content .\graph_api_permissions_friendly_names.json | ConvertFrom-Json
	$friendlyNamesLookup = @{}
	foreach ($entry in $friendlyNames) {
		if ($entry.Application_Identifier) {
			$friendlyNamesLookup[$entry.Application_Identifier] = $entry.Role_Name
		}
		if ($entry.DelegatedWork_Identifier) {
			$friendlyNamesLookup[$entry.DelegatedWork_Identifier] = $entry.Role_Name
		}
	}

    # Preprocess graph_api_permissions_map.json into a hashtable for friendly name lookups
    $permissionMapper = Get-Content .\graph_api_permissions_map.json | ConvertFrom-Json
    $permissionMapperLookup = @{}

    foreach ($permission in $permissionMapper) {
        # Combine Application_Least and DelegatedWork_Least into a single array
        $leastPermissions = @($permission.Application_Least, $permission.DelegatedWork_Least) | Where-Object { $_ -and $_ -ne "Not supported." }

        foreach ($value in $leastPermissions) {
            # Ensure the value is valid and not empty
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                if (-not $permissionMapperLookup.ContainsKey($value)) {
                    $permissionMapperLookup[$value] = @()
                }
                $permissionMapperLookup[$value] += [PSCustomObject]@{
                    Path = $permission.path
                    FullExampleUrl = $permission.full_example_url
                    Method = $permission.method
                    Version = $permission.version
                }
            } else {
                # Debugging: Log invalid or unsupported values
                Write-Host "Skipping invalid or unsupported permission value: $value" -ForegroundColor Yellow
            }
        }
    }

	# Group by PrincipalId
	$groupedAssignments = $appRoleAssignments.AppRoleAssignedTo | Group-Object -Property PrincipalId

	$roleAssignments = @()

	foreach ($group in $groupedAssignments) {

		$principalId = $group.Name
		$firstAssignment = $group.Group | Select-Object -First 1

		# Collect all permissions and URL paths for this principal in a single loop
		$permissions = @()
		$urlPaths = @()

		foreach ($assignment in $group.Group) {
			Pause
			continue
			$currentAppRoleId = $assignment.AppRoleId

			# Lookup friendly name from graph_api_permissions_friendly_names.json
			if ($friendlyNamesLookup.ContainsKey($currentAppRoleId)) {
				$friendlyName = $friendlyNamesLookup[$currentAppRoleId]

				# Add permission details
				$permission = [PSCustomObject]@{
					AppRoleId = $currentAppRoleId
					FriendlyName = $friendlyName
					Id = $assignment.Id
				}
				$permissions += $permission

				# Lookup URL paths from preprocessed permission mapper
				if ($permissionMapperLookup.ContainsKey($friendlyName)) {
					$urlPaths += $permissionMapperLookup[$friendlyName]
				} else {
					# Debugging: Log missing keys
					Write-Host "No URL paths found for friendly name: $friendlyName" -ForegroundColor Yellow
				}
			} else {
				# Debugging: Log missing AppRoleId
				Write-Host "No friendly name found for AppRoleId: $currentAppRoleId" -ForegroundColor Red
			}
		}

		# Create a consolidated object for this principal
		$roleAssignment = [PSCustomObject]@{
			PrincipalDisplayName = $firstAssignment.PrincipalDisplayName
			PrincipalType = $firstAssignment.PrincipalType
			PrincipalId = $principalId
			Permissions = $permissions
			UrlPaths = $urlPaths | Sort-Object -Property Path -Unique
		}
		$roleAssignments += $roleAssignment
	}
	return $roleAssignments
}

Measure-Command -Expression {
	Get-GraphRoleAssignments
}
