# One catalogue defines valid identities for settings, care and rendering.
function Get-PetDefinitions {
    if (-not $script:petDefinitions) {
        $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets/characters/catalog.json'
        $script:petDefinitions = (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).characters
    }
    return $script:petDefinitions
}
function New-CharacterOutfits {
    $result = @{}
    foreach ($definition in (Get-PetDefinitions)) { $result[$definition.id] = [string]$definition.defaultOutfit }
    return $result
}
