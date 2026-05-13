Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend"
$distDir = Join-Path $repoRoot "dist"
$buildDir = Join-Path $repoRoot ".build"
$venvDir = Join-Path $buildDir "packaging-venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$portableDir = Join-Path $distDir "RWA Calculator Portable"
$payloadDir = Join-Path $buildDir "installer-payload"
$bundleZipPath = Join-Path $payloadDir "rwa_calculator_bundle.zip"
$installerExePath = Join-Path $distDir "RWA_Calculator_Setup.exe"
$installerSourcePath = Join-Path $repoRoot "scripts\InstallerStub.cs"
$installerBuildDir = Join-Path $buildDir "installer-build"
$frontendBuildDir = Join-Path $frontendDir "build\windows\x64"
$frontendBundleDir = Join-Path $frontendBuildDir "bundle"
$embeddedPythonZipPath = Join-Path $buildDir "python-embed-amd64.zip"
$backendPackageDir = Join-Path $buildDir "backend-package"
$backendPythonDir = Join-Path $backendPackageDir "python"
$backendSourceDir = Join-Path $backendPackageDir "src"
$backendSeedDataDir = Join-Path $backendSourceDir "data"

function New-CleanDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host "==> $Title" -ForegroundColor Cyan
    & $Action
}

function Assert-LastExitCode {
    param([Parameter(Mandatory = $true)][string]$Context)

    if ($LASTEXITCODE -ne 0) {
        throw "$Context a échoué avec le code $LASTEXITCODE."
    }
}

function Resolve-MSBuildPath {
    $preferredPath = Join-Path $env:ProgramFiles "Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $preferredPath) {
        return $preferredPath
    }

    $candidate = Get-ChildItem (Join-Path $env:ProgramFiles "Microsoft Visual Studio") -Recurse -Filter MSBuild.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) {
        return $candidate
    }

    throw "MSBuild.exe introuvable. Installez Visual Studio avec les outils desktop C++."
}

function Resolve-CSharpCompilerPath {
    $preferredPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (Test-Path $preferredPath) {
        return $preferredPath
    }

    $candidate = Get-ChildItem (Join-Path $env:WINDIR "Microsoft.NET") -Recurse -Filter csc.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) {
        return $candidate
    }

    throw "csc.exe introuvable. Installez le .NET Framework developer pack ou Visual Studio."
}

function Get-PythonVersion {
    return (& $venvPython -c "import sys; print(sys.version.split()[0])").Trim()
}

function Get-PythonTag {
    return (& $venvPython -c "import sys; print(f'python{sys.version_info.major}{sys.version_info.minor}')").Trim()
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path $Source)) {
        return
    }

    $destinationParent = Split-Path -Parent $Destination
    if ($destinationParent) {
        Ensure-Directory -Path $destinationParent
    }
    Copy-Item $Source $Destination -Force
}

function Resolve-PreferredWorkbookPath {
    $directCandidate = Join-Path $backendDir "data\modele_import_rwa.xlsx"
    if (Test-Path $directCandidate) {
        return $directCandidate
    }

    $desktopCandidates = @(
        (Join-Path $HOME "OneDrive\Desktop")
        (Join-Path $HOME "Desktop")
    )

    $workbooks = foreach ($desktop in $desktopCandidates) {
        if (Test-Path $desktop) {
            Get-ChildItem $desktop -Filter "BASE_CALCUL_RWA*.xlsx" -File -ErrorAction SilentlyContinue
        }
    }

    $preferredWorkbook = $workbooks |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($preferredWorkbook) {
        return $preferredWorkbook
    }

    return $null
}

function Copy-BackendSeedData {
    param([Parameter(Mandatory = $true)][string]$TargetDataDir)

    Ensure-Directory -Path $TargetDataDir
    Copy-IfExists -Source (Join-Path $backendDir "data\rwa_data.db") -Destination (Join-Path $TargetDataDir "rwa_data.db")
    Copy-IfExists -Source (Join-Path $backendDir "data\exposure_metadata.json") -Destination (Join-Path $TargetDataDir "exposure_metadata.json")

    $preferredWorkbook = Resolve-PreferredWorkbookPath
    if ($preferredWorkbook) {
        Copy-Item $preferredWorkbook (Join-Path $TargetDataDir "modele_import_rwa.xlsx") -Force
    }
}

Ensure-Directory -Path $distDir
Ensure-Directory -Path $buildDir

if (-not (Test-Path $venvPython)) {
    Invoke-Step -Title "Creation de l'environnement Python de packaging" -Action {
        python -m venv $venvDir
        Assert-LastExitCode -Context "La creation du venv Python"
    }
}

Invoke-Step -Title "Installation des dependances de packaging Python" -Action {
    & $venvPython -m pip install --upgrade pip
    Assert-LastExitCode -Context "La mise a jour de pip"
    & $venvPython -m pip install -r (Join-Path $backendDir "requirements.txt")
    Assert-LastExitCode -Context "L'installation des dependances Python"
}

Invoke-Step -Title "Assemblage du backend Python embarque" -Action {
    $pythonVersion = Get-PythonVersion
    $pythonTag = Get-PythonTag
    $embedUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
    $sitePackagesDir = Join-Path $backendPythonDir "Lib\site-packages"
    $pthFilePath = Join-Path $backendPythonDir "$pythonTag._pth"

    New-CleanDirectory -Path $backendPackageDir
    Ensure-Directory -Path $backendPythonDir
    Ensure-Directory -Path $backendSourceDir
    Ensure-Directory -Path $backendSeedDataDir

    Invoke-WebRequest -Uri $embedUrl -OutFile $embeddedPythonZipPath
    Expand-Archive -Path $embeddedPythonZipPath -DestinationPath $backendPythonDir -Force
    Ensure-Directory -Path $sitePackagesDir

    & $venvPython -m pip install --upgrade --target $sitePackagesDir -r (Join-Path $backendDir "requirements.txt")
    Assert-LastExitCode -Context "L'installation des dependances dans le runtime Python embarque"

    Copy-Item (Join-Path $backendDir "app") $backendSourceDir -Recurse -Force
    Copy-Item (Join-Path $backendDir "database") $backendSourceDir -Recurse -Force
    Copy-Item (Join-Path $backendDir "run_server.py") $backendSourceDir -Force
    Copy-BackendSeedData -TargetDataDir $backendSeedDataDir

    Set-Content -Path $pthFilePath -Encoding Ascii -Value @(
        "$pythonTag.zip",
        ".",
        "Lib\site-packages",
        "..\src",
        "import site"
    )
}

Invoke-Step -Title "Compilation du frontend Flutter Windows" -Action {
    Push-Location $frontendDir
    try {
        flutter clean
        Assert-LastExitCode -Context "flutter clean"
        flutter pub get
        Assert-LastExitCode -Context "flutter pub get"
        flutter build windows --release
        Assert-LastExitCode -Context "flutter build windows --release"
    }
    finally {
        Pop-Location
    }
}

Invoke-Step -Title "Creation explicite du bundle Windows Flutter" -Action {
    $msbuildExe = Resolve-MSBuildPath
    & $msbuildExe (Join-Path $frontendBuildDir "INSTALL.vcxproj") /p:Configuration=Release /p:Platform=x64 /m
    Assert-LastExitCode -Context "La creation du bundle Windows via MSBuild"
}

Invoke-Step -Title "Assemblage du livrable portable" -Action {
    if (-not (Test-Path (Join-Path $frontendBundleDir "rwa_calculator.exe"))) {
        throw "Executable Flutter introuvable dans $frontendBundleDir"
    }
    if (-not (Test-Path (Join-Path $backendPythonDir "python.exe"))) {
        throw "Runtime Python embarque introuvable dans $backendPythonDir"
    }
    if (-not (Test-Path (Join-Path $backendSourceDir "run_server.py"))) {
        throw "Lanceur backend introuvable dans $backendSourceDir"
    }

    New-CleanDirectory -Path $portableDir
    Copy-Item (Join-Path $frontendBundleDir "*") $portableDir -Recurse -Force
    Copy-Item $backendPackageDir (Join-Path $portableDir "backend") -Recurse -Force
}

Invoke-Step -Title "Preparation du paquet d'installation" -Action {
    New-CleanDirectory -Path $payloadDir

    if (Test-Path $bundleZipPath) {
        Remove-Item $bundleZipPath -Force
    }
    Compress-Archive -Path (Join-Path $portableDir "*") -DestinationPath $bundleZipPath -CompressionLevel Optimal
}

Invoke-Step -Title "Compilation de l'installateur EXE autonome" -Action {
    $cscExe = Resolve-CSharpCompilerPath
    New-CleanDirectory -Path $installerBuildDir
    if (Test-Path $installerExePath) {
        Remove-Item $installerExePath -Force
    }

    $compilerArguments = @(
        "/nologo",
        "/target:winexe",
        "/platform:x64",
        "/out:$installerExePath",
        "/resource:$bundleZipPath,RwaCalculator.Bundle.zip",
        "/reference:System.dll",
        "/reference:System.Core.dll",
        "/reference:System.IO.Compression.dll",
        "/reference:System.IO.Compression.FileSystem.dll",
        "/reference:System.Windows.Forms.dll",
        "/reference:Microsoft.CSharp.dll"
    )
    $compilerArguments += $installerSourcePath

    & $cscExe @compilerArguments
    Assert-LastExitCode -Context "La compilation de l'installateur autonome"
    if (-not (Test-Path $installerExePath)) {
        throw "L'installateur autonome n'a pas été généré."
    }
}

Write-Host ""
Write-Host "Portable :" -ForegroundColor Green
Write-Host "  $portableDir"
Write-Host "Installateur EXE :" -ForegroundColor Green
Write-Host "  $installerExePath"
