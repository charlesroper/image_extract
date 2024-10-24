import re
import pyodbc
import binascii
import os

# Database connection details
db_connection_string = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=10.200.1.3;DATABASE=DbArchive;UID=fsc;PWD=&q&oU8eN&l58vU2K"

output_directory = "./extracted_images"

# Create output directory if it doesn't exist
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

try:
    # Connect to the database using pyodbc
    connection = pyodbc.connect(db_connection_string)
    cursor = connection.cursor()

    # Query to get the image data
    query = """
    SELECT TOP 100
        DBA_ROWID,
        b2.dbfile AS image,
        b2.BLOBType,
        DATEADD(SECOND, ARCH_DATE, '1970-01-01 00:00:00') AS [DATE],
        PIA_REFERENCE
    FROM
        DBA_INVOICES_AND_CREDITS iac
    INNER JOIN
        DBA__BLOBS b 
        ON iac.BLOB = b.BLOBHandle
    INNER JOIN
        DBA__BLOBS b2
        ON b.encryptionKey = b2.encryptionKey
    WHERE
        b2.BLOBType = 2
    ORDER BY
        [DATE] DESC;
    """

    # Execute the query
    cursor.execute(query)
    rows = cursor.fetchall()

except Exception as e:
    print(f"Error connecting to database or executing query: {e}")
    exit(1)

# Trackers to maintain file naming count
file_count = {}


# Function to clean the filename
def clean_filename(name):
    # Replace invalid filename characters with an underscore
    return re.sub(r'[\/:*?"<>|]', "_", name)


# Iterate through each row in the result set
for row in rows:
    try:
        dba_rowid = row.DBA_ROWID
        pia_reference = row.PIA_REFERENCE
        image_hex = row.image

        # Convert the hex image data to binary
        if isinstance(image_hex, bytes):
            image_hex = image_hex.hex()
        if image_hex.startswith("0x"):
            image_hex = image_hex[2:]
        image_data = binascii.unhexlify(image_hex)

        # Update the file count for this PIA_REFERENCE
        if pia_reference not in file_count:
            file_count[pia_reference] = 1
        else:
            file_count[pia_reference] += 1

        # Clean the PIA_REFERENCE for use in a filename
        clean_pia_reference = clean_filename(pia_reference)

        # Create the filename using the cleaned PIA_REFERENCE and padded number
        image_number = str(file_count[pia_reference]).zfill(2)
        filename = f"{clean_pia_reference}_{image_number}.tif"
        output_path = os.path.join(output_directory, filename)

        # Write the binary data to a TIF file
        with open(output_path, "wb") as image_file:
            image_file.write(image_data)

        print(f"Saved: {filename}")

    except KeyError as e:
        print(f"Missing key in database row: {e}")
    except binascii.Error as e:
        print(f"Error converting hex to binary for DBA_ROWID {dba_rowid}: {e}")
    except AttributeError as e:
        print(f"Unexpected attribute error: {e}")

print("Extraction complete.")
