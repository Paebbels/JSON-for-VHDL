# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:            Patrick Lehmann
#
#	PowerShell Script:  Compile JSONTestSuite's JSON files with JSON-for-VHDL
#
# Description:
# ------------------------------------
#	TODO
#
# License:
# ==============================================================================
# Copyright 2007-2016 Patrick Lehmann - Dresden, Germany
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# .SYNOPSIS
# This CmdLet compiles the JSONTestSuite with GHDL and QuestaSim.
#
# .DESCRIPTION
# To be written
#
[CmdletBinding()]
param(
	# Show the embedded help page(s)
	[switch]$Help =						$false,
	
	# Run test suite with all simulators
	[switch]$All =						$false,
	# Run test suite with GHDL
	[switch]$GHDL =						$false,
#	# Run test suite with QuestaSim
# 	[switch]$Questa =					$false,
	# Clean up directory before analyzing.
	[switch]$Clean =					$false,
	
	# Set VHDL Standard to '93
	[switch]$VHDL93 =					$false,
	# Set VHDL Standard to '08
	[switch]$VHDL2008 =				$false,
	
	# Skip warning messages. (Show errors only.)
	[switch]$SuppressWarnings = $false,
	# Halt on errors
	[switch]$HaltOnError =			$false,
	
	# Set GHDL executable
	[string]$GHDLBinaryDir =	""
)

function Exit-Script
{	<#
		.PARAMETER ExitCode
		ExitCode of this script run
	#>
	[CmdletBinding()]
	param([int]$ExitCode = 0)
	cd $WorkingDir
	exit $ExitCode
}

# ---------------------------------------------
# save working directory
$WorkingDir =		Get-Location

# Display help if no command was selected
$Help = $Help -or (-not ($All -or $GHDL -or $Questa -or $Clean))

if ($Help)
{	Get-Help $MYINVOCATION.InvocationName -Detailed
	Exit-Script
}
if ($All)
{	$GHDL =			$true
	$Questa =		$true
}

# Functions
function Get-GHDLBinary
{	<#
		.PARAMETER GHDL
		GHDL's binary directory
	#>
	[CmdletBinding()]
	param([string]$GHDL)

	if ($GHDL -ne "")
	{	$GHDLBinary = $GHDL.TrimEnd("\")			+ "\ghdl.exe"	}
	elseif (Test-Path env:GHDL)
	{	$GHDLBinary = $env:GHDL.TrimEnd("\")	+ "\ghdl.exe"	}
	else
	{	$GHDLBinary = "ghdl.exe"														}
	
	if (-not (Test-Path $GHDLBinary -PathType Leaf))
	{	Write-Host "Use adv. options '-GHDLBinaryDir' to set the GHDL executable." -ForegroundColor Red
		Exit-Script -1
	}
	
	return $GHDLBinary
}

function Get-VHDLVariables
{	<#
		.PARAMETER VHDL93
		Undocumented
		.PARAMETER VHDL2008
		Undocumented
	#>
	[CmdletBinding()]
	param(
		[bool]$VHDL93 =		$false,
		[bool]$VHDL2008 = $true
	)
	
	if ($VHDL93)
	{	$VHDLVersion =	"v93"
		$VHDLStandard =	"93c"
		$VHDLFlavor =		"synopsys"
	}
	elseif ($VHDL2008)
	{	$VHDLVersion =	"v08"
		$VHDLStandard = "08"
		$VHDLFlavor =		"synopsys"
	}
	else
	{	$VHDLVersion =	"v93"
		$VHDLStandard = "93c"
		$VHDLFlavor =		"synopsys"
	}
	return $VHDLVersion,$VHDLStandard,$VHDLFlavor
}

function Restore-NativeCommandStream
{	<#
		.SYNOPSIS
		This CmdLet gathers multiple ErrorRecord objects and reconstructs outputs
		as a single line.
		
		.DESCRIPTION
		This CmdLet collects multiple ErrorRecord objects and emits one String
		object per line.
		
		.PARAMETER InputObject
		A object stream is required as an input.
	#>
	[CmdletBinding()]
	param([Parameter(ValueFromPipeline=$true)]$InputObject)

	begin
	{	$LineRemainer = ""	}

	process
	{	if (-not $InputObject)
		{	Write-Host "Empty pipeline!"	}
		elseif ($InputObject -is [System.Management.Automation.ErrorRecord])
		{	if ($InputObject.FullyQualifiedErrorId -eq "NativeCommandError")
			{	Write-Output $InputObject.ToString()		}
			elseif ($InputObject.FullyQualifiedErrorId -eq "NativeCommandErrorMessage")
			{	$NewLine = $LineRemainer + $InputObject.ToString()
				while (($NewLinePos = $NewLine.IndexOf("`n")) -ne -1)
				{	Write-Output $NewLine.Substring(0, $NewLinePos)
					$NewLine = $NewLine.Substring($NewLinePos + 1)
				}
				$LineRemainer = $NewLine
			}
		}
		elseif ($InputObject -is [String])
		{	Write-Output $InputObject		}
		else
		{	Write-Host "Unsupported object in pipeline stream"		}
	}

	end
	{	if ($LineRemainer -ne "")
		{	Write-Output $LineRemainer	}
	}
}

function Write-ColoredGHDLLine
{	<#
		.SYNOPSIS
		This CmdLet colors GHDL output lines.
		
		.DESCRIPTION
		This CmdLet colors GHDL output lines. Warnings are prefixed with 'WARNING: '
		in yellow and errors are prefixed with 'ERROR: ' in red.
		
		.PARAMETER InputObject
		A object stream is required as an input.
		.PARAMETER SuppressWarnings
		Skip warning messages. (Show errors only.)
		.PARAMETER Indent
		Indentation string.
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$true)]
		$InputObject,
		
		[Parameter(Position=1)]
		[switch]$SuppressWarnings = $false,
		[Parameter(Position=2)]
		[string]$Indent = ""
	)

	begin
	{	$ErrorRecordFound = $false	}
	
	process
	{	if ($InputObject -is [String])
		{	if ($InputObject -match ":\d+:\d+:warning:\s")
			{	if (-not $SuppressWarnings)
				{	Write-Host "${Indent}WARNING: "	-NoNewline -ForegroundColor Yellow
					Write-Host $InputObject
				}
			}
			elseif ($InputObject -match ":\d+:\d+:\s")
			{	$ErrorRecordFound	= $true
				Write-Host "${Indent}ERROR: "		-NoNewline -ForegroundColor Red
				Write-Host $InputObject
			}
			elseif ($InputObject -match ":error:\s")
			{	$ErrorRecordFound	= $true
				Write-Host "${Indent}ERROR: "		-NoNewline -ForegroundColor Red
				Write-Host $InputObject
			}
			else
			{	Write-Host "${Indent}$InputObject"		}
		}
		else
		{	Write-Host "Unsupported object in pipeline stream"		}
	}

	end
	{	$ErrorRecordFound		}
}

function Start-Analyze
{	<#
		.PARAMETER GHDLBinary
		Undocumented
		.PARAMETER GHDLOptions
		Undocumented
		.PARAMETER Library
		Undocumented
		.PARAMETER SourceFiles
		Undocumented
		.PARAMETER HaltOnError
		Undocumented
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$GHDLBinary,
		[Parameter(Mandatory=$true)][string[]]$GHDLOptions,
		[Parameter(Mandatory=$true)][string]$Library,
		[Parameter(Mandatory=$true)][string]$VHDLVersion,
		[Parameter(Mandatory=$true)][string[]]$SourceFiles,
		[Parameter(Mandatory=$true)][bool]$HaltOnError
	)
	# Write-Host "Compiling library '$Library' ..." -ForegroundColor Yellow
	$ErrorCount = 0
	foreach ($File in $SourceFiles)
	{	# Write-Host "Analyzing file '$File'" -ForegroundColor DarkCyan
		$InvokeExpr = "$GHDLBinary " + ($GHDLOptions -join " ") + " --work=$Library " + $File + " 2>&1"
		# Write-Host "  $InvokeExpr" -ForegroundColor DarkGray
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredGHDLLine $SuppressWarnings "  "
		if ($LastExitCode -ne 0)
		{	$ErrorCount += 1
			if ($HaltOnError)
			{	break		}
		}
	}
	# return $ErrorCount
}

function Start-Execution
{	<#
		.PARAMETER GHDLBinary
		Undocumented
		.PARAMETER GHDLOptions
		Undocumented
		.PARAMETER Library
		Undocumented
		.PARAMETER TopLevel
		Undocumented
		.PARAMETER HaltOnError
		Undocumented
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$GHDLBinary,
		[Parameter(Mandatory=$true)][string[]]$GHDLOptions,
		[Parameter(Mandatory=$true)][string]$Library,
		[Parameter(Mandatory=$true)][string]$VHDLVersion,
		[Parameter(Mandatory=$true)][string]$TopLevel,
		[Parameter(Mandatory=$true)][bool]$HaltOnError
	)
	$ErrorCount = 0
	# Write-Host "Executing '$TopLevel'" -ForegroundColor DarkCyan
	$InvokeExpr = "$GHDLBinary " + ($GHDLOptions -join " ") + " --work=$Library " + $TopLevel + " 2>&1"
	# Write-Host "  $InvokeExpr" -ForegroundColor DarkGray
	$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredGHDLLine $SuppressWarnings "  "
	if ($LastExitCode -ne 0)
	{	$ErrorCount += 1
		if ($HaltOnError)
		{	break		}
	}
	# return $ErrorCount
}

# Setup directories

# Setup files
$GHDLBinary =						Get-GHDLBinary $GHDLBinaryDir
$ConfigPackageFile =		"config.pkg.vhdl"

# define global GHDL Options
$VHDLVersion,$VHDLStandard,$VHDLFlavor = Get-VHDLVariables $VHDL93 $VHDL2008
$GHDLAnalyzeOptions =	@("-a", "-fexplicit", "-frelaxed-rules", "--mb-comments", "--warn-binding", "--ieee=$VHDLFlavor", "--no-vital-checks", "--std=$VHDLStandard")
$GHDLRunOptions =			@("-r", "-fexplicit", "-frelaxed-rules", "--mb-comments", "--warn-binding", "--ieee=$VHDLFlavor", "--no-vital-checks", "--std=$VHDLStandard")

# Cleanup directories
# ==============================================================================
if ($Clean)
{	Write-Host "Cleaning up vendor directory ..." -ForegroundColor Yellow
	rm *.cf
}

# Running JSONTestSuite with GHDL
# ==============================================================================
if ($GHDL)
{	$Library =					"json"
	$SourceFiles = (
		"..\vhdl\JSON.pkg.vhdl"
	)
	
	$ErrorCount += 0
	Start-Analyze $GHDLBinary $GHDLAnalyzeOptions $Library $VHDLVersion $SourceFiles $HaltOnError
	$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)

	
	$SourceDirectory =	".\test_parsing"
	$FileNames =				dir -Path ./test_parsing *.json | Sort-Object -Property Name
	$TestCase =					0
	foreach ($File in $FileNames)
	{	$TestCase +=		1
		$TestName =			$File.Name.TrimEnd(".json")
		$SourceFile = 	"$SourceDirectory\$File"
		$Library =			"test_$TestCase"
		
		Write-Host ("Test: {0,-50}  VHDL library: {1}" -f $TestName, $Library) -ForegroundColor DarkCyan
		$ConfigPackageContent = "package config is`n`tconstant C_JSON_FILE : STRING := `"$SourceFile`";`nend package;"
		$ConfigPackageContent | Out-File $ConfigPackageFile -Encoding Ascii
		
		$SourceFiles =	(
			$ConfigPackageFile,
			"TopLevel.vhdl"
		)
	
		$ErrorCount += 0
		Start-Analyze $GHDLBinary $GHDLAnalyzeOptions $Library $VHDLVersion $SourceFiles $HaltOnError
		$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)
		
		Start-Execution $GHDLBinary $GHDLRunOptions $Library $VHDLVersion "TopLevel" $HaltOnError
		$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)
	}
	
	Write-Host "--------------------------------------------------------------------------------"
	Write-Host "Running JSONTestSuite with GHDL " -NoNewline
	if ($ErrorCount -gt 0)
	{	Write-Host "[FAILED]" -ForegroundColor Red
		Write-Host "  $ErrorCount errors"
	}
	else
	{	Write-Host "[SUCCESSFUL]" -ForegroundColor Green	}
}

if ($Questa)
{	Write-Host "[ERROR]: Not implemented." -ForegroundColor Red
	Exit-Script -1
}

Exit-Script 0
