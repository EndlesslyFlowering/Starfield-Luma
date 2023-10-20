$ErrorActionPreference = "Stop"


$ShaderOutputDirectory = Get-Content "${PSScriptRoot}\target_folder.txt"
$DistDirectory = "${PSScriptRoot}\..\Plugin\dist\Data\shadersfx\"
$ShaderOutputEmbedPDB = $false


$main =
{
	#HDRComposite
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "FF1A"
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "600FF1A" -Defines "APPLY_TONEMAPPING", "APPLY_CINEMATICS"
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "700FF1A" -Defines "APPLY_BLOOM", "APPLY_TONEMAPPING", "APPLY_CINEMATICS"
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "800FF1A" -Defines "APPLY_MERGED_COLOR_GRADING_LUT"
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "E00FF1A" -Defines "APPLY_TONEMAPPING", "APPLY_CINEMATICS", "APPLY_MERGED_COLOR_GRADING_LUT"
	Compile-Shader -Type "ps" -TechniqueName "HDRComposite" -TechniqueId "F00FF1A" -Defines "APPLY_BLOOM", "APPLY_TONEMAPPING", "APPLY_CINEMATICS", "APPLY_MERGED_COLOR_GRADING_LUT"

	#Copy
	Compile-Shader -Type "ps" -TechniqueName "Copy" -TechniqueId "400FF59"  -Defines "OUTPUT_TO_R10G10B10A2"
	Compile-Shader -Type "ps" -TechniqueName "Copy" -TechniqueId "2000FF59" -Defines "OUTPUT_TO_R16G16B16A16_SFLOAT"

	#FilmGrain
	Compile-Shader -Type "ps" -TechniqueName "FilmGrain" -TechniqueId "FF75" -Entry "main"

	#ColorGradingMerge
	Compile-Shader -Type "cs" -TechniqueName "ColorGradingMerge" -TechniqueId "FF81"

	#ContrastAdaptiveSharpening
	#Compile-Shader -Type "cs" -TechniqueName "ContrastAdaptiveSharpening" -TechniqueId "FF94" -Entry "main"
	Compile-Shader -Type "cs" -TechniqueName "ContrastAdaptiveSharpening" -TechniqueId "100FF94" -Defines "USE_PACKED_MATH" -AdditionalParams "-enable-16bit-types", "-Wno-conversion"
	Compile-Shader -Type "cs" -TechniqueName "ContrastAdaptiveSharpening" -TechniqueId "300FF94" -Defines "USE_PACKED_MATH", "USE_UPSCALING" -AdditionalParams "-enable-16bit-types", "-Wno-conversion"

	#PostSharpen
	Compile-Shader -Type "ps" -TechniqueName "PostSharpen" -TechniqueId "FF9A"

	#ScaleformComposite
	Compile-Shader -Type "ps" -TechniqueName "ScaleformComposite" -TechniqueId "FFAA"

	#BinkMovie
	Compile-Shader -Type "ps" -TechniqueName "BinkMovie" -TechniqueId "FFAB"
}


function Run-DXC {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Arguments
	)

	$processInfo = New-Object System.Diagnostics.ProcessStartInfo
	$processInfo.FileName = "${PSScriptRoot}\..\tools\dxc_2023_08_14\bin\x64\dxc.exe"
	$processInfo.Arguments = $Arguments
	$processInfo.RedirectStandardError = $true
	$processInfo.RedirectStandardOutput = $true
	$processInfo.UseShellExecute = $false
	$processInfo.CreateNoWindow = $true

	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = $processInfo
	$process.Start() | Out-Null
	$process.WaitForExit()

	# Output the result
	$stdout = $process.StandardOutput.ReadToEnd()
	$stderr = $process.StandardError.ReadToEnd()

	if ($process.ExitCode -ne 0) {
		Write-Error "An error occurred during shader compilation:`n$stderr"
	}

	if ($stdout.Length -gt 0) {
		Write-Host $stdout
	}
}

function Compile-Shader {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Type,

		[Parameter(Mandatory = $true)]
		[string]$TechniqueName,

		[Parameter(Mandatory = $true)]
		[string]$TechniqueId,

		[Parameter(Mandatory = $false)]
		[string]$Entry = $Type.ToUpper(),

		[parameter(Mandatory = $false)]
		[array]$Defines,

		[parameter(Mandatory = $false)]
		[array]$AdditionalParams
	)

	$inputHlslName = "${TechniqueName}_${Type}.hlsl"
	$outputBinName = "${TechniqueName}_${TechniqueId}_${Type}.bin"
	$outputSigName = "${TechniqueName}_${TechniqueId}_rsg.bin"

	$inputHlslPath = "${PSScriptRoot}\${TechniqueName}\${inputHlslName}"
	$stagedBinPath = "${PSScriptRoot}\${TechniqueName}\${outputBinName}"
	$stagedSigPath = "${PSScriptRoot}\${TechniqueName}\${outputSigName}"

	Write-Host "Compiling ${outputBinName}..."

	# Build the shader in its staging directory
	$args = "`"${inputHlslPath}`" -WX -Fo `"${stagedBinPath}`" -T ${Type}_6_6 -E ${Entry} "

	if ($ShaderOutputEmbedPDB -eq $true) {
		$args = $args + "-Qembed_debug -Zi "
	}

	foreach ($define in $Defines) {
		$args = $args + "-D ${define} "
	}

	foreach ($param in $AdditionalParams) {
		$args = $args + "${param} "
	}

	Run-DXC -Arguments $args

	# Extract and strip away the DXIL root signature
	# TODO: Can extractrootsignature and Qstrip_rootsignature be used in the same operation?
	Run-DXC -Arguments "-dumpbin `"${stagedBinPath}`" -extractrootsignature -Fo `"${stagedSigPath}`""
	Run-DXC -Arguments "-dumpbin `"${stagedBinPath}`" -Qstrip_rootsignature -Fo `"${stagedBinPath}`""

    # Copy the resulting bins to the dist directory.
    New-Item -Force -ItemType Directory -Path "${DistDirectory}\${TechniqueName}" | Out-Null
    Copy-Item -Force -Path $stagedBinPath -Destination "${DistDirectory}\${TechniqueName}\${outputBinName}"
    Copy-Item -Force -Path $stagedSigPath -Destination "${DistDirectory}\${TechniqueName}\${outputSigName}"

	# Move the resulting bins to the game directory. Move-Item is to avoid partial reads when live shader editing
	# is enabled.
	New-Item -Force -ItemType Directory -Path "${ShaderOutputDirectory}\${TechniqueName}" | Out-Null
	Move-Item -Force -Path $stagedBinPath -Destination "${ShaderOutputDirectory}\${TechniqueName}\${outputBinName}"
	Move-Item -Force -Path $stagedSigPath -Destination "${ShaderOutputDirectory}\${TechniqueName}\${outputSigName}"
}

try {
	& $main
}
catch {
	Write-Host -ForegroundColor Red $_
	Pause
}
