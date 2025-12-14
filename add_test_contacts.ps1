# PowerShell script to add test contacts to Android emulator
# Run this script to populate the emulator with test contacts for testing the contact picker

$emulatorName = "emulator-Pixel_8"  # Change this if using a different emulator

Write-Host "Adding test contacts to emulator: $emulatorName" -ForegroundColor Cyan

# List of test contacts to add
$testContacts = @(
    @{
        name = "Alice Johnson"
        phone = "5551234567"
        email = "alice.johnson@example.com"
    },
    @{
        name = "Bob Smith"
        phone = "5559876543"
        email = "bob.smith@example.com"
    },
    @{
        name = "Carol White"
        phone = "5551111111"
        email = "carol.white@example.com"
    },
    @{
        name = "David Brown"
        phone = "5552222222"
        email = "david.brown@example.com"
    },
    @{
        name = "Emergency Mom"
        phone = "5553333333"
        email = "mom@example.com"
    }
)

# SQL to create contacts in the Contacts database
$insertSql = ""

foreach ($contact in $testContacts) {
    # Insert raw_contact
    $insertSql += "INSERT INTO raw_contacts (account_id, account_type, account_name, sourceid, version, dirty, deleted, sync1, sync2, sync3, sync4) VALUES (1, 'com.google', 'unknown@gmail.com', NULL, 1, 0, 0, NULL, NULL, NULL, NULL);"
    
    # Get last inserted ID for the contact
    $insertSql += "`nINSERT INTO data (raw_contact_id, mimetype_id, is_primary, is_super_primary, data_version, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15) VALUES ((SELECT last_insert_rowid()), (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/name'), 0, 0, 0, '{0}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);" -f $contact.name
    
    # Add phone
    $insertSql += "`nINSERT INTO data (raw_contact_id, mimetype_id, is_primary, is_super_primary, data_version, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15) VALUES ((SELECT last_insert_rowid()), (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/phone_v2'), 1, 1, 0, '{0}', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);" -f $contact.phone
    
    # Add email
    $insertSql += "`nINSERT INTO data (raw_contact_id, mimetype_id, is_primary, is_super_primary, data_version, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15) VALUES ((SELECT last_insert_rowid()), (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/email_v2'), 0, 0, 0, '{0}', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);" -f $contact.email
}

# Write the SQL to a temporary file
$tempSql = "$env:TEMP\add_contacts.sql"
Set-Content -Path $tempSql -Value $insertSql
Write-Host "SQL script written to: $tempSql" -ForegroundColor Green

# Execute the SQL via adb shell
Write-Host "`nAttempting to add contacts via adb..." -ForegroundColor Yellow

try {
    # Use adb to execute the SQL commands
    & adb -s $emulatorName shell sqlite3 /data/data/com.android.providers.contacts/databases/contacts2.db < $tempSql
    Write-Host "✓ Contacts added successfully!" -ForegroundColor Green
} catch {
    Write-Host "✗ Error adding contacts: $_" -ForegroundColor Red
    Write-Host "`nTrying alternative method (adb push + execute)..." -ForegroundColor Yellow
    
    # Alternative: Push the file to the device and execute
    & adb -s $emulatorName push $tempSql /sdcard/add_contacts.sql
    & adb -s $emulatorName shell "sqlite3 /data/data/com.android.providers.contacts/databases/contacts2.db < /sdcard/add_contacts.sql"
    
    Write-Host "✓ Contacts added via push method!" -ForegroundColor Green
}

# Cleanup
Remove-Item -Path $tempSql -Force -ErrorAction SilentlyContinue

Write-Host "`n📱 Test contacts have been added. Run the app again to see them in the Device Contacts tab." -ForegroundColor Cyan
