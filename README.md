PowerShell script to recursively transcode video files using ffmpeg

You must edit PsFpeg-Transcode.ps1 to set $inPath and $outPath, which must be folders/directories, not specific files. Edit other options as you see fit.

Ffmpeg CLI: https://ffmpeg.org/download.html

Mediainfo CLI: https://mediaarea.net/en/MediaInfo/Download

FAQ

Q: Why are my videos not being transcoded?

A: Check your input folder and ensure it's correct.

Q: Why is hardware transcoding not working?

A: Ensure your video drivers are updated. Check logs
