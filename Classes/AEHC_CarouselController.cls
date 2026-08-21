public with sharing class AEHC_CarouselController {
    
    /**
* DTO for UI cards returned to LWC.
*/
    public class CarouselCardWrapper {
        @AuraEnabled public String title       { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String url         { get; set; }
        @AuraEnabled public String category    { get; set; }
        @AuraEnabled public String imageUrl    { get; set; }
    }
    
    /**
* DTO for publication cards returned to LWC.
*/
    public class PublicationWrapper {
        @AuraEnabled public String id              { get; set; }
        @AuraEnabled public String applicationName { get; set; }
        @AuraEnabled public String publicationName { get; set; }
        @AuraEnabled public String schedule        { get; set; }
        @AuraEnabled public String lastUpdated     { get; set; }
        @AuraEnabled public String url             { get; set; }
    }
    
    @TestVisible
    static Boolean forceException = false;
    @TestVisible
    static Map<String, AEHC_Carousel_Config__mdt> testMdt;
    
    /**
* Returns cards filtered by the current user's role preferences.
* The method is cacheable and safe for LDS-backed LWC consumption.
*
* @return List<CarouselCardWrapper> - normalized cards for UI rendering.
*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFilteredCards(String currUserPreference) {
        Map<String, Object> result  = new Map<String, Object>();
        // Prepare context for logging
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'getFilteredCards',
                'userId' => UserInfo.getUserId()
                };
                    // Map values to AEHC_Error_Event__c picklist options using provided value sets.
                    String componentType = 'Apex'; // Component type picklist
        String componentName = 'AEHC_CarouselController';
        String operation     = 'Query';       // Operation picklist
        String severity      = 'P3';          // Severity picklist (normal path context)
        String category      = 'Unknown';     // Category picklist default
        String orgEnv        = getCurrentEnvironment(); // Derive environment dynamically
        
        try {
            // Fetch current user's preference in USER MODE with FLS and sharing enforced.
            // Using LIMIT 1 and selective WHERE by Id; only the needed field is selected.
            User currentUser = [
                SELECT AEHC_Preference__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            String rawPrefs = currentUser.AEHC_Preference__c;
            
            // Return early if no preferences set (empty UI state in LWC).
            if (String.isBlank(rawPrefs)) {
                result.put('status', 404);
                return result;
            }
            
            // Build a normalized set of categories from the semicolon-delimited preference string.
            // Trim whitespace and ignore empty tokens.
            Set<String> userCategories = new Set<String>();
            for (String token : rawPrefs.split(';')) {
                String t = token != null ? token.trim() : null;
                if (!String.isBlank(t)) {
                    userCategories.add(t);
                }
            }
            
            if (userCategories.isEmpty()) {
                result.put('status', 404);
                return result;
            }
            
            // Use Custom Metadata cache; no runtime SOQL required for configuration.
            // getAll() is O(n) on the number of records but uses platform metadata cache.
            List<AEHC_Carousel_Config__mdt> allMdt;
            
            if (Test.isRunningTest() && testMdt != null) {
                allMdt = testMdt.values();
            } else {
                allMdt = [
                    SELECT AEHC_Tile_Title__c, AEHC_Tile_Description__c,
                    AEHC_RedirectURL__c, AEHC_Group__c,
                    AEHC_Image__c, AEHC_Active__c, AEHC_Sort_Order__c
                    FROM AEHC_Carousel_Config__mdt
                    WHERE AEHC_Active__c = true
                    ORDER BY AEHC_Sort_Order__c ASC NULLS LAST
                ];
            }
            if (allMdt == null || allMdt.isEmpty()) {
                result.put('status', 404);
                return result;
            }
            
            // Pre-size the results list for small perf gain (optional).
            List<CarouselCardWrapper> results = new List<CarouselCardWrapper>();
            
            // collect images first
            
            Set<String> imageNames = new Set<String>();
            
            // Filter metadata by user categories and project into wrapper.
            for (AEHC_Carousel_Config__mdt card : allMdt) {
                // Skip null records defensively
                if (card == null) continue;
                
                // Only include cards whose Group__c is in the user's categories
                if (userCategories.contains(card.AEHC_Group__c) && card.AEHC_Active__c) {
                    CarouselCardWrapper w = new CarouselCardWrapper();
                    w.title       = card.AEHC_Tile_Title__c;
                    w.description = card.AEHC_Tile_Description__c;
                    w.url         = card.AEHC_RedirectURL__c;
                    w.category    = card.AEHC_Group__c;
                    w.imageUrl    = card.AEHC_Image__c;
                    results.add(w);
                }
            }
            
            if(results.isEmpty()) {
                result.put('status', 404);
                return result;
            }
            
            if (forceException) {
                throw new AuraHandledException('Forced exception for testing');
            }
            result.put('status', 200);
            result.put('data', results);
            return result;
        } catch (Exception ex) {
            // Log exception via centralized logger; return safe fallback for LWC
            AEHC_Logger.logException(
                ex,
                componentType,
                componentName,
                operation,
                null,
                'P2', // Exception severity
                category,
                context,
                orgEnv
            );
            result.put('status', 500);
            result.put('message', ex.getMessage());
            return result;
        }
    }
    
    /**
* Returns hardcoded publication data for subscriber persona carousel.
* The method is cacheable and safe for LDS-backed LWC consumption.
*
* @return List<PublicationWrapper> - publication cards for UI rendering.
*/
    @AuraEnabled(cacheable=true)
    public static List<PublicationWrapper> getPublications() {
        
        String baseUrl = getSiteBaseUrl();
        List<PublicationWrapper> publications = new List<PublicationWrapper>();
        
        // ✅ Fetch latest 10 publications
        List<AEHC_Asset__c> assets = [
            SELECT
            Id,
            Name,
            AEHC_Application__r.Name,
            AEHC_Frequency__c,
            LastModifiedDate
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = NULL  AND
            RecordType.DeveloperName = 'AEHC_Publication' 
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        
        for (AEHC_Asset__c a : assets) {
            
            PublicationWrapper pub = new PublicationWrapper();
            pub.id = a.Id;
            pub.applicationName = a.AEHC_Application__r?.Name;
            pub.publicationName = a.Name;
            
            // ✅ Schedule (safe fallback)
            pub.schedule = String.isNotBlank(a.AEHC_Frequency__c)
                ? a.AEHC_Frequency__c
                : 'N/A';
            
            // ✅ Format last updated
            pub.lastUpdated = formatRelativeDate(a.LastModifiedDate);
            
            // ✅ URL to detail page
            pub.url = baseUrl + '/data-publication-details?id=' + a.Id;
            
            publications.add(pub);
        }
        
        return publications;
    }
    
    private static String formatRelativeDate(Datetime dt) {
        if (dt == null) return '';
        
        Long diffMillis = Datetime.now().getTime() - dt.getTime();
        Long days = diffMillis / (1000 * 60 * 60 * 24);
        
        if (days < 1) return 'Today';
        if (days < 7) return days + ' days ago';
        if (days < 30) return (days / 7) + ' weeks ago';
        if (days < 365) return (days / 30) + ' months ago';
        
        return (days / 365) + ' years ago';
    }
    
    
    /**
* Helper method to dynamically get the Experience Cloud site's base URL.
* This ensures URLs work across different environments (dev, qa, uat, prod).
* Uses Site.getBaseUrl() which returns the actual site URL (e.g., *.site.com)
* instead of the org domain (*.salesforce.com).
*
* @return String - the base URL for the Experience Cloud site (e.g., https://domain.site.com/aeh/s)
*/
    private static String getSiteBaseUrl() {
        // Site.getBaseUrl() returns the full site URL including the path prefix
        // Example: https://kpmg-aeh--aehdevfeb.sandbox.my.site.com/aeh
        String siteBaseUrl = Site.getBaseUrl();
        
        // If running in a site context, Site.getBaseUrl() returns the site URL
        // If not in a site context (e.g., running in tests), fall back to org domain
        if (String.isBlank(siteBaseUrl)) {
            // Fallback for non-site context (e.g., test execution)
            siteBaseUrl = System.Url.getOrgDomainUrl().toExternalForm() + '/aeh';
        }
        
        // Append '/s' to complete the site path
        return siteBaseUrl + '/s';
    }
    
    // Simple environment resolver using org characteristics; adjust as needed for your SDLC
    private static String getCurrentEnvironment() {
        // If a Custom Metadata/Setting or Label exists in your org to drive env, plug it in here.
        // Fallback heuristic based on org id prefix and domain name patterns commonly used in sandboxes.
        // Note: getSalesforceBaseUrl() is removed after v58; use getOrgDomainUrl() instead.
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
            // try to distinguish by naming conventions if present
            if (domain.contains('dev') || domain.contains('--dev')) return 'Dev';
            if (domain.contains('qa')  || domain.contains('--qa'))  return 'QA';
            if (domain.contains('uat') || domain.contains('--uat')) return 'UAT';
            return 'QA'; // generic sandbox default
        }
        return 'Prod';
    }
    
}