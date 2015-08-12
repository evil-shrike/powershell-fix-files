# powershell-fix-files
PowerShell script `Fix-TS.ps1` for managing file names and attributes.

Please see full story in my blog - http://techblog.dorogin.com/2015/08/organize-your-image-files.html

# USAGE
```
Fix-TS.ps1 <Path> [-filter <filter>] [-fix] [-all] [-rename <rename-options>] [-source <timestamp-source>]
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
```
