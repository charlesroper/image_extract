# NOTE 1: Converting to PNG (and other formats) turned out to be far less
# efficient than using the existing TIFF with CCITT Group 4 compression

# NOTE 2: Although parallel processing using PowerShell made good use of all CPU
# cores, there is a huge overhead in spinning up a process for each conversion,
# making the conversion process twice as slow as using IrfanView's single
# threaded batch conversion.

# Define the directories
$inputDirectory = ".\extracted_images"
$outputDirectory = ".\extracted_images_pwsh"

# Create the output directory if it does not exist
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

# Get all .tif files in the current directory and its subdirectories
$files = Get-ChildItem -Path $inputDirectory -Filter *.tif

# Get number of physical cores for paralellisation 
$physicalCores = (Get-CimInstance Win32_Processor | Measure-Object NumberOfCores -Sum).Sum

# Run each conversion task in parallel
$files | ForEach-Object -Parallel {
    # Use $using: to access variables from the parent scope

    # Output the name of the file being processed
    Write-Host "Processing $($_.Name)"

    # Create the output file path by combining the output directory and the new file name
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) + ".png"
    $outputFile = Join-Path -Path $using:outputDirectory -ChildPath $fileName

    # Run the ImageMagick conversion command
    # Using compresses level of 1 for speed
    magick -quiet -regard-warnings $_.FullName -strip -quality 100 -define png:compression-level=1 $outputFile

} -ThrottleLimit $physicalCores
