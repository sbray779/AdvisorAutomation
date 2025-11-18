# This script is called by Terraform to deploy the Logic App workflow definition
param(
    [string]$WorkflowJsonFile,
    [string]$LogicAppId,
    [string]$Location,
    [string]$ManagedIdentityId,
    [string]$TagsJson
)

Write-Host "Deploying Logic App workflow definition..."
Write-Host "Reading workflow definition from: $WorkflowJsonFile"

# Load the workflow definition
$workflowDef = Get-Content -Path $WorkflowJsonFile -Raw | ConvertFrom-Json
$tags = $TagsJson | ConvertFrom-Json

# Construct the body
$bodyObj = @{
    location = $Location
    properties = @{
        definition = $workflowDef
        parameters = @{}
        state = "Enabled"
    }
    identity = @{
        type = "UserAssigned"
        userAssignedIdentities = @{
            $ManagedIdentityId = @{}
        }
    }
    tags = $tags
}

# Convert to JSON and save to temp file
$body = $bodyObj | ConvertTo-Json -Depth 20 -Compress
$tempFile = [System.IO.Path]::GetTempFileName()
$body | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

try {
    # Deploy via Azure REST API
    Write-Host "Calling Azure REST API..."
    $uri = "$LogicAppId`?api-version=2019-05-01"
    az rest --method PUT --uri $uri --body `"@$tempFile`"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Workflow definition deployed successfully!"
    } else {
        Write-Error "Failed to deploy workflow definition. Exit code: $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    # Clean up temp file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
