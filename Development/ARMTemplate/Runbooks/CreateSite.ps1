Param
(
    [Parameter (Mandatory = $false)][int]$listItemID = -1
)

$VerbosePreference = "Continue"
Write-Verbose "Startup 1"
$VerbosePreference = "SilentlyContinue"

$Global:AzureAutomation = (Get-Command "Get-AutomationVariable" -ErrorAction SilentlyContinue)
if ($AzureAutomation) { 
    . .\EUMSites_Helper.ps1
    . .\CreateSite-Customizations.ps1

    if (-not (Check-RunbookLock)) {
        return "Suspended"
    }
}
else {
    . $PSScriptRoot\EUMSites_Helper.ps1
    . $PSScriptRoot\CreateSite-Customizations.ps1
}

$VerbosePreference = "Continue"
Write-Verbose -Verbose -Message "Startup 2"

LoadEnvironmentSettings

$global:VerbosePreference = "Continue"
Write-Verbose -Verbose -Message "Startup 3"

if ($listItemID -eq -1) {
    $connLandingSite = Helper-Connect-PnPOnline -Url $SiteCollectionFullURL
    $pendingSiteCollections = Get-PnPListItem -Connection $connLandingSite -List $SiteListName -Query "
        <View>
            <Query>
                <Where>
                    <And>
                        <IsNull>
                            <FieldRef Name='EUMSiteCreated'/>
                        </IsNull>
                        <Eq>
                            <FieldRef Name='_ModerationStatus' />
                            <Value Type='ModStat'>0</Value>
                        </Eq>
                    </And>
                </Where>
            </Query>
            <ViewFields>
                <FieldRef Name='ID'></FieldRef>
                <FieldRef Name='Title'></FieldRef>
            </ViewFields>
        </View>"
}
else {
    class SiteCollection {
        [string]$ID
        [string]$Title
    }

    $siteCollection = [siteCollection]::new()
    $siteCollection.ID = $listItemID

    $pendingSiteCollections = @($siteCollection)
}

$pendingSiteCollections | ForEach-Object {
    $pendingSite = $_
    $listItemID = $pendingSite.ID

    if (ProvisionSite -listItemID $listItemID) {
        # Apply and implementation specific customizations
        if (CreateSite-Customizations -listItemID $spListItem.Id) {
            # Reconnect to the master site and update the site collection list
            $connLandingSite = Helper-Connect-PnPOnline -Url $SiteCollectionFullURL

            # Set the site created date
            [Microsoft.SharePoint.Client.ListItem]$spListItem = Set-PnPListItem -List $SiteListName -Identity $listItemID -Values @{ "EUMSiteCreated" = [System.DateTime]::Now } -Connection $connLandingSite

            return "Success"
        }
        else {
            return "Error applying customizations"
        }
    }
    else {
        return "Error provisioning site"
    }
}
