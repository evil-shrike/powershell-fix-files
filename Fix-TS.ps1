Param(
	$path,
  [string]$source = "name",
  [string[]]$filter,
  [switch]$all,
  [switch]$fix,
  [string[]]$rename
)
#[datetime]::ParseExact("2012:03:16 19:54:14", "yyyy:MM:dd HH:mm:ss", $null) | Write-Host 
#exit
function GetTakenData($image) {
  try {
    $takenData = $image.GetPropertyItem(36867).Value
    if ($takenData -eq $null) {
        return $null
    }
    $takenValue = [System.Text.Encoding]::Default.GetString($takenData, 0, $takenData.Length - 1)
    return $takenValue
  } catch {
    return $null
  } finally {
    $image.Dispose()
  }
}
if (!$path) {
	"USAGE: <Path> [-filter <filter>] [-fix] [-all] [-rename <rename-options>] [-source <timestamp-source>]
  path    - path to a folder with files to check/fix
  -filter - array of wildcards to filter files, e.g. '*.jpg' , '*.jpg,*.mp4' (without quotes)
            EXAMPLE: ./fixts.ps1 /path/to/ -filter *.jpg,*.png
  -fix    - apply fixes (by default the tool only reports on found issues without fixing them)
            EXAMPLE: ./fixts.ps1 /path/to/ -fix
  -all    - show all found files (by default only files with issues will be reported)
            EXAMPLE: ./fixts.ps1 /path/to/ -all
            
  -source - specify the source for timespamp, 
    where <timestamp-source>:
      name  - extract timestamps from file names with pattern 'yyyyMMdd-HHmmss' (used by default)
      exif  - extract timestamps from EXIF metadata (Date Taken)
    EXAMPLES:
      ./fixts.ps1 /path/to/ -source exif
      
  -rename - rename files based on their timestamps,
    where <rename-options>:
      remove-prefix             - remove all prefixes
      remove-prefix:<prefix>    - remove the <prefix>
      remove-prefix[:!<prefix>] - remove all or all except <prefix> prefixes from the beginning of file name
      add-prefix:<prefix>       - add <prefix> fpr all files
      add-prefix:<ext1>=<prefix>|<ext2>=<prefix> - add prefixes basing on files extenstion
      rebuild                   - assing name with timestamp using pattern 'yyyyMMdd-HHmmss' (keep extension)
    EXAMPLES: 
      ./fixts.ps1 /path/to/ -rename rebuild
        name files with timespamp, e.g. '20151207_245959.jpg'
      ./fixts.ps1 /path/to/ -rename remove-prefix
        remove all prefixes before year part, e.g. 'IMG_20151207_245959.jpg' will be '20151207_245959.jpg'
      ./fixts.ps1 /path/to/ -rename remove-prefix:!PANO 
        remove all prefixes except 'PANO', i.e. 'PANO_20151207_245959.jpg' will not change
      ./fixts.ps1 /path/to/ -rename add-prefix:jpg=IMG_|mp4=VID_|avi=VID_ 
        add prefix IMG_ for all *.jpg, add prefix VID_ for all *.mp3 and *.avi files
"
	exit
}
if (!(Test-Path $path)) {
  Write-Host -ForegroundColor Red "Not existing path was specified: $path"
  exit 1
}
if ($fix) {
  Write-Host "Running in fix mode"
}
if (!$filter) {
  $filter = "*.jpg","*.mp4"
}
#[Reflection.Assembly]::Load('System.Drawing.dll') | Out-Null
[Reflection.Assembly]::LoadFile('C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll') | Out-Null
$needCorrect = $false
$issueCount = 0
$filesParsed = 0
Get-ChildItem -Path $path\* -r -Include $filter | ForEach-Object {
  $filename = $_.Name
  $filepath = $_.FullName
  $fileext = $_.Extension
  
  # the source of thruth is file name
  if ($source -eq "name") {
    $match = [regex]::matches($filename, "^[^\d]*(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})")
    if (!$match.Success) {
      Write-Host -ForegroundColor Red "Could not extract timestamp from file name '$filename'. Ignoring."
      return
    }
    $parts = $match.Groups
    $years = $parts[1]
    $months = $parts[2]
    $days = $parts[3]
    $hours = $parts[4]
    $minutes = $parts[5]
    $seconds = $parts[6]
    $dateSrc = [datetime]::ParseExact("$years.$months.$days-${hours}:${minutes}:${seconds}","yyyy.MM.dd-HH:mm:ss",$null)
    if (!$dateSrc) {
      Write-Host -ForegroundColor Red "Could not parse timestamp extracted from file name '$filename'. Ignoring."
      return
    }
  } elseif ($source -eq "exif") {
    $image = New-Object System.Drawing.Bitmap -ArgumentList $filepath
    $dateExif = GetTakenData($image)
    #Write-Output "Extracted EXIF '$dateExif'"
    if ($dateExif) {
      $dateSrc = [DateTime]::ParseExact($dateExif, 'yyyy:MM:dd HH:mm:ss', $null)
    }
    if (!$dateSrc) {
      Write-Host -ForegroundColor Red "Could not extract EXIF metadata from file '$filename'. Ignoring."
      return
    }
  }
  
  $filesParsed++
#  Write-Verbose "  parsed date: $years.$months.$days - ${hours}:${minutes}:${seconds}"
  $dateAttr = (Get-ItemProperty $filepath -Name LastWriteTime).LastWriteTime
  if ($all) {
    Write-Output "$filename : extracted($source): $dateSrc, attr: $dateAttr"
  }
  if (!$dateAttr) {
    Write-Host -ForegroundColor Red "Could not get LastWriteTime attribute value for $filename"
  }
  $compare = [DateTime]::Compare($dateSrc, $dateAttr)
  $diff = ($dateSrc - $dateAttr).TotalSeconds 
  # fix file attr DateModified
  if (($diff -gt 2) -or ($diff -lt -2)) {
    # NOTE: for exFAT there could be diffrence in seconds, as it has precision in double seconds
    $needCorrect = $true
    $issueCount++
    if ($fix) {
      Set-ItemProperty $filepath -Name LastWriteTime -Value $dateSrc
      if ($all) {
          Write-Host -ForegroundColor Yellow "  Correcting file timestamp: from $dateAttr to $dateSrc"
      } else {
          Write-Host -ForegroundColor Yellow "${filename}: correcting file timestamp: from $dateAttr to $dateSrc"
      }
    } else {
      if ($all) {
        Write-Host -ForegroundColor Yellow "  incorrect file timestamp: $dateAttr, parsed timestamp: $dateSrc"
      } else {
        Write-Host -ForegroundColor Yellow "${filename}: incorrect file timestamp: $dateAttr, parsed timestamp: $dateSrc"
      }
    }
  }
  # fix file name
  if ($rename) {
    <#
    $rename can a combination of the following:
      add-prefix:jpg=IMG_|mp4=VID_
      add-prefix:*=AND_
      keep-prefix
      remove-prefix
      keep-suffix
      remove-suffix
      rebuild
    #>    
    $newname = ""
    $years = $dateSrc.Year
    $months = "{0:D2}" -f $dateSrc.Month
    $days = "{0:D2}" -f $dateSrc.Day
    $hours = "{0:D2}" -f $dateSrc.Hour
    $minutes = "{0:D2}" -f $dateSrc.Minute
    $seconds = "{0:D2}" -f $dateSrc.Second
    foreach ($item in $rename) {
      if ($item.startsWith("rebuild")) {
        $newname = "${years}${months}${days}_${hours}${minutes}${seconds}${fileext}"
      } elseif ($item.startsWith("remove-prefix")) {
        $newname = $null
        # Handle "remove-prefix:!PANO_" - means to remove all prefixes except "PANO_"
        if ($item.startsWith("remove-prefix:!")) {
          $item = $item.Substring("remove-prefix:!".length)
          if ($item -and $filename.StartsWith($item)) {
            # current file name starts with prefix to ignore
            continue;
          }
        } elseif ($item.startsWith("remove-prefix:")) {
          # remove only specified prefix
          $item = $item.Substring("remove-prefix:".length)
          if ($item  -and $filename.startsWith($item)) {
            $newname = $filename.Substring($item.Length)
          }
        }
        # IMG_20151231_245959_001.jpg => 20151231_245959_001.jpg
        if (!$newname) {
          # remove any prefix
          $idx = $filename.IndexOf("${years}${months}${days}")
          if ($idx -gt 0) {
            $newname = $filename.Substring($idx)
          }
        }
      } elseif ($item.startWith("add-prefix")) {
        # Handle "add-prefix:"
        #   add-prefix:Canon_ - add prefix to all files
        #   add-prefix:jpg=IMG_|mp4=VID_ - speficy prefix basing on file extenstion
        $item = $item.Substring("add-prefix:".Length)
        if ($item) {
          if ($item.Contains("=")) {
            # mapping
            $parts = $item.split('|')
            foreach($item in $parts) {
              if ($fileext -and ($fileext.Substring(1) -eq $item)) {
                $newname = "{$item}${years}${months}${days}_${hours}${minutes}${seconds}${fileext}"
              }
            }
          } else {
            # prefix for all
            $newname = "{$item}${years}${months}${days}_${hours}${minutes}${seconds}${fileext}"
          }
        }
      }
    }
    if ($newname) {
      if ($filename -ne $newname ) {
        Write-Host "Renaming '$filename' to '$newname'"
        $needCorrect = $true
        $issueCount++
        if ($fix) {
          Rename-Item $filepath -NewName $newname
        }
      }
    }
  }
}

Write-Host "Processed $filesParsed files"
if (($issueCount -gt 0) -and !$fix) {  
  Write-Host "To correct found $issueCount issues re-run with -fix switch"
} elseif (($issueCount -gt 0) -and $fix) {  
  Write-Host "$issueCount files were fixed"
} else {
  Write-Host "No issues were found"
}
