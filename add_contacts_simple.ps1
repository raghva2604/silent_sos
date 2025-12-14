# Simple script to add test contacts to Android emulator using adb shell sqlite3

# Get the list of available emulators
Write-Host "Available emulators:" -ForegroundColor Cyan
& adb devices -l | Select-String "emulator"

# Prompt user to select emulator
$emulatorId = Read-Host "Enter emulator ID (e.g., emulator-5554 or just 5554)"

# Clean up emulator ID if needed
if (-not $emulatorId.StartsWith("emulator-")) {
    $emulatorId = "emulator-$emulatorId"
}

Write-Host "`nAdding test contacts to: $emulatorId" -ForegroundColor Green

# Add test contacts using SQL INSERT statements
$contacts = @(
    "INSERT INTO raw_contacts (account_id, account_type, account_name, sourceid, version, dirty, deleted, sync1, sync2, sync3, sync4) VALUES (1, 'com.google', 'account@gmail.com', NULL, 1, 0, 0, NULL, NULL, NULL, NULL);",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/name'), 1, 'Alice Johnson' FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1, data2) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/phone_v2'), 1, '5551234567', 1 FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    
    "INSERT INTO raw_contacts (account_id, account_type, account_name, sourceid, version, dirty, deleted, sync1, sync2, sync3, sync4) VALUES (1, 'com.google', 'account@gmail.com', NULL, 1, 0, 0, NULL, NULL, NULL, NULL);",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/name'), 1, 'Bob Smith' FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1, data2) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/phone_v2'), 1, '5559876543', 1 FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    
    "INSERT INTO raw_contacts (account_id, account_type, account_name, sourceid, version, dirty, deleted, sync1, sync2, sync3, sync4) VALUES (1, 'com.google', 'account@gmail.com', NULL, 1, 0, 0, NULL, NULL, NULL, NULL);",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/name'), 1, 'Carol White' FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1, data2) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/phone_v2'), 1, '5551111111', 1 FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    
    "INSERT INTO raw_contacts (account_id, account_type, account_name, sourceid, version, dirty, deleted, sync1, sync2, sync3, sync4) VALUES (1, 'com.google', 'account@gmail.com', NULL, 1, 0, 0, NULL, NULL, NULL, NULL);",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/name'), 1, 'Emergency Mom' FROM raw_contacts ORDER BY id DESC LIMIT 1;",
    "INSERT INTO data (raw_contact_id, mimetype_id, is_primary, data1, data2) SELECT id, (SELECT _id FROM mimetypes WHERE mimetype='vnd.android.cursor.item/phone_v2'), 1, '5553333333', 1 FROM raw_contacts ORDER BY id DESC LIMIT 1;"
)

Write-Host "Running SQL commands..." -ForegroundColor Yellow

# Execute each SQL command
foreach ($sql in $contacts) {
    try {
        & adb -s $emulatorId shell sqlite3 /data/data/com.android.providers.contacts/databases/contacts2.db "$sql" 2>&1
    }
    catch {
        Write-Host "Error executing SQL (may be normal): $_" -ForegroundColor Yellow
    }
}

Write-Host "`n✓ Test contacts insertion completed!" -ForegroundColor Green
Write-Host "`nRestart the app or navigate away from the contacts picker and back to refresh the list." -ForegroundColor Cyan

# Verify contacts were added
Write-Host "`nVerifying contacts (this may show an error if contacts are in background):" -ForegroundColor Yellow
& adb -s $emulatorId shell sqlite3 /data/data/com.android.providers.contacts/databases/contacts2.db "SELECT COUNT(*) as contact_count FROM raw_contacts;" 2>&1
