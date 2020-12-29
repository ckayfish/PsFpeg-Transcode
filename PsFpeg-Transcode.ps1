####################################################################################
##                                                                                ##
#  Psfpeg-Transcode - PowerShell script to transcode video files using ffmpeg      #
#                   - Original goal was to convert AVC to HEVC to reduce storage   #
#                   - Requires ffmpeg and mediainfo CLI exe's to be available      #
#                   - Review and set options. inPath & outPath most important      #
#                                                                                  #
#  Creates an mkv file with many non-HEVC codecs transcoded to HEVC                #
#     - Define codecs and file extenstions to transcode                            #
#     - Set the ffmpeg preset and crf                                              #
#     - Log script execution and ffmpeg output of each transcode                   #
#     - Choose to overwrite files or not                                           #
#     - Tag output file with your personal handle                                  #
#                                                                                  #
#                                                                                  #
#                                                                                  #
#  v1.0 2020-12-29                                                                 #
##                                                                                ##
####################################################################################

### SET THESE VARIABLES EITHER AT COMMANDLINE OR IN SCRIPT
## Set 3rd party executables
# Full path name to ffmpeg.exe. Simply "ffmpeg.exe" if in path
$ffmpeg="ffmpeg.exe" 
#Full path name to mediainfo.exe. Simply "mediainfo.exe" if in path
$mediainfo="D:\Program Files\MediaInfo\Cli\mediainfo.exe"

## Set Input and output paths
# Path to recursively find video files to process
$inPath="M:\mediadisk1\media\tv\hdtv\"
#$inPath="M:\mediadisk1\media\tv\hdtv\"
# Path to output video files. The ful subpath from the inPath is preserved
$outPath="M:\mediadisk2\media\tv\hdtv\"

# The preset determines compression efficiency and encoding speed. Valid presets are ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
$preset="fast"   # "medium" is default

#Quality RF setting. Smaller is more lossless, default is 22
$crf="20"

# Choose if we should overwrite existing video files in the destination
[bool]$noOverwrite=$true  #Set to $false to overwite all files
# [bool]$noOverwrite=$true    #Set to $true to NOT overwrite files

# Your person encoder tag to add to the postfile of the base file name. Leave blank or comment out to not use
$encoderTag="PING"

####################################################################################
##### Start by only changing above ^^^^^ for your specific environmnent
####################################################################################

## Variables that control how the script runs

#Path where log files should be created ($PSScriptRoot is default, the location of the script being executed)
$logPath="$PSScriptRoot\logs"
# Log prefix
$logPrefix="psfpegTranscode"

# File extentions in source path to transcode
$extentions = @(".mkv",".mp4",".mov",".avi")

# All strings that would match the codecs identified in source file names or Video format
# .. These vaulues will be replaced in the filename, and only video streams identified my mediainfo with these names will be transcoded
$codecNames=@("X264", "X.264", "H264", "H.264", "AVC","x264","MPEG-4 Visual","XviD")

## Variables specific to ffmpeg
# The Target codec name. This is used only to rename the file
$newCodecName="HEVC"

# Name of library used to create output video codec
$newCodecLib="libx265"

###
##### EDIT BELOW HERE AT YOUR OWN RISK AND ONLY IF YOU KNOW WHAT YOU ARE DOING #####
####################################################################################
####################################################################################


## Future release variables
# Set to $true of you only want to keep audio tracks labeled as English, $false to keep all audio tracks
# Must be left at $false for release 1.0
[bool]$audioEnglishOnly = $false


### Function to create timestamped output intended for logging to file and/or screen
function TimeLog-Output  {
 param( [string]$logOut)  
 "$((Get-Date).ToString("yyyy-MM-dd-HH:mm.ss")) - $logOut"
}

### MAIN FUNCTION
# Start logging
$batchTimer = [System.Diagnostics.Stopwatch]::StartNew()
$logFile = "$logPath\$logPrefix-$((Get-Date).ToString("yyyyMMddHHmmss"))-BATCH.log"
Start-Transcript -Path $logFile -Append
#Log start of batch transcoding
TimeLog-Output "Begin Batch Transcode at: '$inPath'"

TimeLog-Output "vvv All script variables"
"ffmpeg:        $ffmpeg"
"mediainfo:     $mediainfo"
"inPath:        $inPath"
"outPath:       $outPath"
"preset:        $preset"
"crf:           $crf"
"audioLanguage: $audioLanguage"
"noOverwrite:   $noOverwrite"
"encoderTag:    $encoderTag"
"logPath:       $logPath"
"logPrefix:     $logPrefix"
"extentions:    $([string]$extentions)"
"codecnames:    $([string]$codecNames)"
"newCodecName:  $newCodecName"
"newCodecLib:   $newCodecLib"
"crf:           $crf"
TimeLog-Output "^^^ End script variables"

#Initialize counter for number of transcodes.
[int]$transcodeCount=0
#For every file discovered recursively in source path with defined extensions
get-childitem $inPath -recurse | where {$extentions.Contains($_.extension)} | % {
  TimeLog-Output "***** Begin Processing file *****"
  $srcFile=$_.FullName
  TimeLog-Output "Processing:      '$srcFile'"

  # Get video format/codec
  $srcFormat= "$(& $mediainfo --Inform='Video;%Format%' $srcFile)"
  
  #Transcode only IF the video format detected in the source file matches a codec name targeted for transcoding
  if (!$codecNames.Contains($srcFormat)){
    # Desired source format not detected. Skip source file.
    TimeLog-Output "Source Format:   '$srcFormat' NOT accepted for transcoding. Skipping."
  } else { # Source format IS targetted for transcode 
    # Capture details of input media
    TimeLog-Output "Source Format:   '$srcFormat' accepted for transcoding"
    $srcWidth=  "$(& $mediainfo --Inform='Video;%Width%' $srcFile)"
    $srcHeight= "$(& $mediainfo --Inform='Video;%Height%' $srcFile)"
    $srcBitrate="$(& $mediainfo --Inform='Video;%BitRate%' $srcFile)"
    TimeLog-Output "Source Width:    $srcWidth"
    TimeLog-Output "Source Height:   $srcHeight"
    TimeLog-Output "Source Bitrate:  $([math]::Round($($srcBitrate/1048576),2)) Mbps"

    # Create destination folder if it doesn't exist.
    $outfilePath= $_.DirectoryName.Replace($inPath,$outPath)
    If(!(test-path $outfilePath)) {New-Item -ItemType Directory -Force -Path $outfilePath }

    # Get string for source file name before renaming it for the output file
    if (($encoderTag) -And ($encoderTag -ne "")) {
      $outfileName = "$($_.BaseName).$encoderTag.mkv"
    } else {
      $outfileName = "$($_.BaseName).mkv"
    }

    # Replace old codec names with new codec name
    $codecNames | % { 
      $outfileName = $outfileName.Replace("$_","$newCodecName") 
      # TimeLog-Output "$_ $newCodecName $outfileName"
    }
    # $codecNames | % { $outfileName = $outfileName.Replace("$_","$newCodecName") }
    #Initialize destination file name
    $destFile= "$outfilePath\$outfileName"

    # If destination file exists and noOverwrite is true
    If((test-path $destFile) -and ($noOverwrite)) {
      TimeLog-Output "noOverwrite:     $noOverwrite"
      TimeLog-Output "Output file:     '$destFile' already exists. Skipping..."
      TimeLog-Output "** Set noOverwrite to false if you want to overwrite existing files"
    } else {
      
      ##### Create array of arguments to pass to ffmpeg. These define how the file is transcoded.
      $args = @()
      # Overwrite if got this far
      $args += "-y"
      # Identify input file
      $args += "-i"
      $args += "`"$srcFile`""
      # Identify target video codec library
      $args += "-c:v"
      $args += $newCodecLib
      $args += "-x265-params"
      $args += "crf=$($crf)"
      # Deinterlace video
      $args += "-vf"
      $args += "yadif=1"
      # Use selected encode preset
      $args += "-preset"
      $args += "$preset"

      #Get details of all audio tracks and send to output
      $audioTracksArray = ($(& $mediainfo "`"$srcFile`"" "`"--Inform=Audio;%ID%,%Language%,%Language/String%,%Format%,%CodecID%\r\n`""))
      TimeLog-Output "Audio tracks found in source file..."
      "ID,LangCode,LangString,Format,Codec"
      $audioTracksArray

      # Count number of tracks that are English
      $numEnglishAudioTracks = ($audioTracksArray | select-string -pattern "English").length
      TimeLog-Output "Number of English audio tracks: $numEnglishAudioTracks"

      # If audio tracks exists with selected language, passthrough only those. Else passthough all audio tracks
      # NOT IMPLIMENTED IN v1.0
      if (($numEnglishAudioTracks -gt 0) -and ($audioEnglishOnly)) {
        TimeLog-Output "Passing English audio tracks only"
        # TODO Figure out how to set options to copy English (or other languages) only)
      } else { # No audio tracks found for selected langauge. Copy all of them.
        TimeLog-Output "Passing ALL audio tracks"
        $args += "-c:a"
        $args += "copy"
      }

      # Set file/container type hardcoded to mkv
      $args += "-f"
      $args += "matroska"
      # Finally, identify output file
      $args += "`"$destFile`""

      # Log all arguments
      TimeLog-Output "vvv Arguments passed to '$ffmpeg'"
      [string]$args
      TimeLog-Output "Creating output:    $destFile"

      $fileOutLog="$logPath\$logPrefix-$((Get-Date).ToString("yyyyMMddHHmmss"))-$outfileName.$preset.crf$crf.log"

      # Execute ffmpeg CLI with arguments and capture elaped time
      TimeLog-Output "Logging output to:  $fileOutLog"
      $fileTimer = [System.Diagnostics.Stopwatch]::StartNew()
      & $ffmpeg $args  2>&1 >$fileOutLog
      $fileTimer.Stop()
      TimeLog-Output "Finished Creating: $destFile"
      $transcodeCount++
      $dstFormat= "$(& $mediainfo --Inform='Video;%Format%'     $destFile)"
      $dstWidth=  "$(& $mediainfo --Inform='Video;%Width%'      $destFile)"
      $dstHeight= "$(& $mediainfo --Inform='Video;%Height%'     $destFile)"
      $dstBitrate="$(& $mediainfo --Inform='Video;%BitRate%'    $destFile)"
      TimeLog-Output "Dest Format:     $dstFormat"
      TimeLog-Output "Dest Width:      $dstWidth"
      TimeLog-Output "Dest Height:     $dstHeight"
      TimeLog-Output "Dest Bitrate:    $([math]::Round($($dstBitrate/1048576),2)) Mbps"
      TimeLog-Output "Elapsed time:    $($fileTimer.Elapsed)"
      TimeLog-Output "Outfilesize (MB):$dstWidth"
      TimeLog-Output "Batch time:      $($batchTimer.Elapsed)"
      TimeLog-Output "# files complete :$transcodeCount"
      } #Else file exists && no overwrite
    } # End transcode of targeted file
      
  } # For every file found in path
$batchTimer.Stop()
TimeLog-Output "*****  End Batch Transcode  *****"
TimeLog-Output "Number of files transcoded: $transcodeCount"
TimeLog-Output "Batch Elapsed Time:         $($batchTimer.Elapsed)"
## Goodbye
# End Main and all logging
Stop-Transcript
