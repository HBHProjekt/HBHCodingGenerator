param(
    [string]$Workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-XlsxRows([string]$Path) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $ns = [System.Xml.XmlNamespaceManager]::new([System.Xml.NameTable]::new())
        $ns.AddNamespace('m', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
        $ns.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
        $ns.AddNamespace('p', 'http://schemas.openxmlformats.org/package/2006/relationships')

        function Read-Entry($Zip, [string]$Name) {
            $entry = $Zip.GetEntry($Name)
            if ($null -eq $entry) { return $null }
            $reader = [System.IO.StreamReader]::new($entry.Open())
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        $shared = @()
        $sharedXml = Read-Entry $archive 'xl/sharedStrings.xml'
        if ($sharedXml) {
            [xml]$doc = $sharedXml
            $shared = @($doc.SelectNodes('//m:si', $ns) | ForEach-Object {
                (($_.SelectNodes('.//m:t', $ns) | ForEach-Object { $_.InnerText }) -join '')
            })
        }
        [xml]$workbook = Read-Entry $archive 'xl/workbook.xml'
        [xml]$rels = Read-Entry $archive 'xl/_rels/workbook.xml.rels'
        $targets = @{}
        foreach ($rel in $rels.SelectNodes('//p:Relationship', $ns)) { $targets[$rel.Id] = $rel.Target }
        $result = [System.Collections.Generic.List[object]]::new()
        foreach ($sheet in $workbook.SelectNodes('//m:sheets/m:sheet', $ns)) {
            $sheetName = $sheet.name
            $target = $targets[$sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')]
            $entryName = if ($target.StartsWith('/')) { $target.TrimStart('/') } elseif ($target.StartsWith('xl/')) { $target } else { "xl/$target" }
            [xml]$sheetDoc = Read-Entry $archive $entryName
            foreach ($row in $sheetDoc.SelectNodes('//m:sheetData/m:row', $ns)) {
                $indexed = @{}
                foreach ($cell in $row.SelectNodes('./m:c', $ns)) {
                    $ref = $cell.r
                    $col = 0
                    foreach ($letter in [regex]::Match($ref, '^[A-Z]+').Value.ToCharArray()) { $col = $col * 26 + ([int]$letter - [int][char]'A' + 1) }
                    $value = ''
                    if ($cell.t -eq 's') {
                        $idx = [int]$cell.v
                        if ($idx -ge 0 -and $idx -lt $shared.Count) { $value = $shared[$idx] }
                    } elseif ($cell.t -eq 'inlineStr') {
                        $value = (($cell.SelectNodes('.//m:t', $ns) | ForEach-Object { $_.InnerText }) -join '')
                    } else { $value = [string]$cell.v }
                    $indexed[$col] = $value.Trim()
                }
                if ($indexed.Count -gt 0) {
                    $width = ($indexed.Keys | Measure-Object -Maximum).Maximum
                    $cells = for ($i = 1; $i -le $width; $i++) { if ($indexed.ContainsKey($i)) { $indexed[$i] } else { '' } }
                    $result.Add([pscustomobject]@{ sheet = $sheetName; rowNumber = [int]$row.r; cells = @($cells) })
                }
            }
        }
        return $result.ToArray()
    } finally { $archive.Dispose() }
}

$cciPath = Join-Path $Workspace 'DSS\CCI_komplet_20220910.xlsx'
$cci = @(Read-XlsxRows $cciPath | Where-Object { $_.sheet -in @('Funkční systém', 'Technický systém', 'Komponenty') -and $_.rowNumber -ge 6 })
$entityPath = Join-Path $PSScriptRoot 'data\ifc4x3_entities.json'
$descriptionPath = Join-Path $PSScriptRoot 'data\ifc4x3_descriptions_cs.json'
$entities = Get-Content -Raw $entityPath | ConvertFrom-Json -AsHashtable
$descriptions = Get-Content -Raw $descriptionPath | ConvertFrom-Json -AsHashtable
$payload = [ordered]@{ cci = $cci; ifc = $entities; descriptions = $descriptions }
$json = $payload | ConvertTo-Json -Depth 100 -Compress
"window.HBH_DATA = $json;" | Set-Content -Encoding utf8 (Join-Path $PSScriptRoot 'data\catalog-data.js')
Write-Host "Generated browser catalogs: $($cci.Count) CCI rows, $($entities.Count) IFC entities."
