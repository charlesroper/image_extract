# Define the directories
$inputDirectory = ".\extracted_images"
$outputDirectory = ".\extracted_images_pwsh"

# Create the output directory if it does not exist
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

# Get all .tif files in the input directory
$files = Get-ChildItem -Path $inputDirectory -Filter *.tif -File -Recurse | Select-Object -First 200

# Get the number of physical cores and logical processors
$physicalCores = (Get-CimInstance Win32_Processor | Measure-Object NumberOfCores -Sum).Sum
$logicalProcessors = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum

# Function to run the processing with a specified throttle limit
function Run-Processing {
    param (
        [string]$testName,
        [int]$throttleLimit
    )

    Write-Host "`nRunning test: $testName (ThrottleLimit = $throttleLimit)" -ForegroundColor Cyan

    # Measure the execution time
    $executionTime = Measure-Command {
        $files | ForEach-Object -Parallel {
            # Use $using: to access variables from the parent scope

            # Output the name of the file being processed
            Write-Host "Processing $($_.Name)"

            # Create the output file path by combining the output directory and the new file name
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName) + ".png"
            $outputFile = Join-Path -Path $using:outputDirectory -ChildPath $fileName

            # Run the ImageMagick conversion command
            magick -quiet -regard-warnings $_.FullName -strip -define png:compression-level=1 $outputFile

        } -ThrottleLimit $throttleLimit
    }

    Write-Host "Test '$testName' completed in $($executionTime.TotalSeconds) seconds." -ForegroundColor Green
}

# Run the processing using all physical cores
Run-Processing -testName "Physical Cores" -throttleLimit $physicalCores

# Run the processing using all logical processors
Run-Processing -testName "Logical Processors" -throttleLimit $logicalProcessors
