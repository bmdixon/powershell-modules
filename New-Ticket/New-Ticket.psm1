function New-Ticket([String] $reference, [String] $prefix = 'H') {
    if ($reference -match '^(\d*)\/(\d*)$') {
        $ticketNumber = $Matches[1]
        $ticketPart = $Matches[2]
        $ticketRef = "$prefix$($ticketNumber)-$($ticketPart)"
        $filename = "$($ticketRef).md"
        New-Item $ticketRef -ItemType Directory -ErrorAction SilentlyContinue | out-null
        Set-Location $ticketRef
        New-Item $filename -ItemType File -ErrorAction SilentlyContinue | out-null
        Add-Content -path $filename @"
# REQUIREMENTS


# TASK NOTES


# ENABLE NOTES


# DEPLOYMENT INSTRUCTIONS


// cSpell:ignore
"@
    
        Start-Process ".\$filename"
    }
}