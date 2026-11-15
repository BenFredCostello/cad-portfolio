# Portfolio sync: run daily by Windows Task Scheduler (see setup.ps1).
#
# 1. Finds CAD files you've made or changed since the last run and copies them into _inbox\
#    (it skips Inventor OldVersions, "(1)" duplicate copies, files already published, and anything in ignore.txt).
#    The inbox is never published. To publish a file, move it into a project's cad\ or models\ folder.
#    To start a new project, copy projects\_template to projects\<new-name> and edit project.json.
# 2. Uses Autodesk Inventor (if installed) to export an STL for any published .ipt/.iam
#    that doesn't have one yet, so the website can show it in 3D.
# 3. Rebuilds manifest.json, then commits and pushes. GitHub Pages serves the site straight from main.

$ErrorActionPreference = 'Continue'
$Repo   = Split-Path -Parent $PSScriptRoot
$Inbox  = Join-Path $Repo '_inbox'
$State  = Join-Path $Repo 'tools\last-sync.txt'
$Ignore = Join-Path $Repo 'tools\ignore.txt'
$Log    = Join-Path $Repo 'tools\sync.log'
function Log($m) { "$(Get-Date -Format s)  $m" | Tee-Object -FilePath $Log -Append }

$Watch = @(
  "$env:USERPROFILE\Downloads",
  "$env:USERPROFILE\OneDrive\Documents",
  "$env:USERPROFILE\OneDrive - The University of Auckland\UoA_Docs"
) | Where-Object { Test-Path $_ }

$CadExt = '.ipt','.iam','.idw','.dwg','.step','.stp','.stl','.3mf','.f3d','.sldprt','.sldasm','.iges','.igs'
$Since  = if (Test-Path $State) { [datetime](Get-Content $State) } else { (Get-Date).AddDays(-14) }
$Now    = Get-Date
$Skip   = @('OldVersions','Content Center Files','node_modules','.git','.venv','AppData','_inbox')
$IgnorePatterns = if (Test-Path $Ignore) { Get-Content $Ignore | Where-Object { $_ -and -not $_.StartsWith('#') } } else { @() }

Set-Location $Repo
git pull --quiet 2>&1 | Out-Null

# Hashes of everything already published, so re-downloads or copies of the same file are skipped
$Published = @{}
Get-ChildItem (Join-Path $Repo 'projects') -Recurse -File | ForEach-Object {
  $Published[(Get-FileHash $_.FullName -Algorithm SHA1).Hash] = $true
}

# ---- 1. Collect new CAD files into the inbox ----
New-Item -ItemType Directory -Force $Inbox | Out-Null
$new = 0
foreach ($root in $Watch) {
  Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $CadExt -contains $_.Extension.ToLower() -and $_.LastWriteTime -gt $Since } |
    Where-Object { $p = $_.FullName; -not ($Skip | Where-Object { $p -like "*\$_\*" }) } |
    Where-Object { $_.BaseName -notmatch '\(\d+\)$' -and $_.BaseName -notmatch '\.\d{4}$' -and $_.Name -notlike '~*' } |
    Where-Object { $n = $_.Name; -not ($IgnorePatterns | Where-Object { $n -like $_ }) } |
    ForEach-Object {
      $h = (Get-FileHash $_.FullName -Algorithm SHA1).Hash
      if (-not $Published[$h]) {
        $dest = Join-Path $Inbox $_.Name
        Copy-Item $_.FullName $dest -Force
        $new++
      }
    }
}
if ($new) { Log "$new new or changed CAD file(s) copied to _inbox" }

# ---- 2. Export STLs with Inventor for published parts without a model ----
$needs = Get-ChildItem (Join-Path $Repo 'projects') -Recurse -File -Include *.ipt,*.iam |
  Where-Object { $_.Directory.Name -eq 'cad' } |
  Where-Object {
    $stl = Join-Path $_.Directory.Parent.FullName ("models\" + ($_.BaseName -replace '[\s_()]+','-').Trim('-').ToLower() + '.stl')
    -not (Test-Path $stl) -and -not (Test-Path ($stl + '.skip'))
  }
if ($needs) {
  try {
    $inv = New-Object -ComObject Inventor.Application
    $inv.SilentOperation = $true
    foreach ($f in $needs) {
      $models = Join-Path $f.Directory.Parent.FullName 'models'
      New-Item -ItemType Directory -Force $models | Out-Null
      $stl = Join-Path $models ((($f.BaseName -replace '[\s_()]+','-').Trim('-').ToLower()) + '.stl')
      try {
        $doc = $inv.Documents.Open($f.FullName, $false)
        $doc.SaveAs($stl, $true)
        $doc.Close($true)
        Log "Exported $($f.Name) -> models\$(Split-Path $stl -Leaf)"
      } catch {
        Log "Could not export $($f.Name): $($_.Exception.Message)"
        New-Item -ItemType File -Force ($stl + '.skip') | Out-Null
      }
    }
    $inv.Quit()
  } catch {
    Log "Inventor not available, skipping STL export"
  }
}

# ---- 3. Publish ----
python build.py 2>&1 | Out-Null
git add -A projects manifest.json 2>&1 | Out-Null
if (git status --porcelain projects manifest.json) {
  git commit -m "Portfolio sync $(Get-Date -Format 'yyyy-MM-dd')" --quiet
  git push --quiet
  Log "Published changes"
}
$Now.ToString('s') | Set-Content $State
