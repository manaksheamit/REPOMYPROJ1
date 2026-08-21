public with sharing class AEHC_DataPublicationCatalogController{
    
    public class ResponseClass {
        @AuraEnabled public Id id;
        @AuraEnabled public String application;
        @AuraEnabled public String publication;
        @AuraEnabled public String schedule;
        @AuraEnabled public Datetime lastUpdated;        
    }
    
    @AuraEnabled(cacheable=false)
    public static List<ResponseClass> fetchAssets(
        String searchKey,
        String application,
        String environment,
        Integer offsetSize,
        Integer limitSize
    ) {
        List<String> whereClauses = new List<String>();
        List<ResponseClass> results;
        //temp fix show Active dev version as default
        if(String.isEmpty(environment)) {
            environment = 'Dev';
        }
        if(String.isEmpty(environment)) {
            
            /*if (String.isNotBlank(application)) {
                whereClauses.add('AEHC_Application__r.Name = :application');
            }
            
            if (String.isNotBlank(searchKey) && searchKey.length() >= 3) {
                searchKey = '%' + searchKey + '%';
                whereClauses.add(
                    '(AEHC_Application__r.Name LIKE :searchKey OR Name LIKE :searchKey)'
                );
            }
            
            whereClauses.add('RecordType.DeveloperName = \'AEHC_Publication\'');
            //whereClauses.add('AEHC_Is_Active__c = true');
            
            String soql =
                'SELECT Id, AEHC_Application__r.Name, AEHC_Environment__c, Name, LastModifiedDate ' +
                'FROM AEHC_Asset__c ' +
                (whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ')) +
                ' ORDER BY LastModifiedDate DESC ' +
                ' LIMIT :limitSize OFFSET :offsetSize';
            
            // Step 1: Fetch publications
            List<AEHC_Asset__c> publications = Database.query(soql);
            // Step 2: Collect Publication Ids
            Set<Id> pubIds = new Set<Id>();
            for (AEHC_Asset__c pub : publications) {
                pubIds.add(pub.Id);
            }
            
            // Step 3: Fetch Schema (Frequency)
            List<AEHC_Asset__c> schemaList = new List<AEHC_Asset__c>();

            if (!pubIds.isEmpty()) {

                schemaList = [SELECT Id, AEHC_Publication__c, AEHC_Frequency__c, AEHC_Is_Active__c, AEHC_Schema_Version__c, CreatedDate
                                FROM AEHC_Asset__c WHERE AEHC_Publication__c IN :pubIds AND AEHC_Environment__c = 'Dev' 
                                AND AEHC_Is_Subscription__c = false
                                AND AEHC_Is_Active__c = true ORDER BY AEHC_Publication__c,
                                AEHC_Schema_Version__c DESC, CreatedDate DESC];
            }
            
            // Step 4: Map latest schema per publication
            Map<Id, AEHC_Asset__c> activeVersions = new Map<Id, AEHC_Asset__c>();

            for (AEHC_Asset__c rec : schemaList) {

                /* Active Version*/
                /*if (rec.AEHC_Is_Active__c) {
                    activeVersions.put(rec.AEHC_Publication__c, rec);
                }
            }

            Map<Id, AEHC_Asset__c> pubToSchema = new Map<Id, AEHC_Asset__c>();

            for (Id pubId : pubIds) {
                if (activeVersions.containsKey(pubId)) {
                    pubToSchema.put(pubId, activeVersions.get(pubId));
                } 
            }
            
            // Step 5: Build response
            results = new List<ResponseClass>();
            
            for (AEHC_Asset__c a : publications) {
                
                ResponseClass dto = new ResponseClass();
                dto.id = a.Id;
                dto.application = a.AEHC_Application__r.Name;
                dto.publication = a.Name;
                dto.lastUpdated = a.LastModifiedDate;
                
                // Use frequency as schedule
                dto.schedule = String.isBlank(pubToSchema.get(a.Id).AEHC_Frequency__c) ? 'Not Scheduled' : pubToSchema.get(a.Id).AEHC_Frequency__c;
                
                results.add(dto);
            }*/
        } else {
            
            if (String.isNotBlank(application))  whereClauses.add('AEHC_Publication__r.AEHC_Application__r.Name = :application');
            whereClauses.add('AEHC_Environment__c = :environment');
            whereClauses.add('AEHC_Is_Active__c = true');
            whereClauses.add('AEHC_Is_Subscription__c = false');
            whereClauses.add('AEHC_Publication__c != null');
            whereClauses.add('RecordType.DeveloperName = \'' + AEHC_Constant.RECORDTYPENAME_ASSET_VERSION + '\'');
            
            if (String.isNotBlank(searchKey) && searchKey.length() >= 3) {
                searchKey = '%' + searchKey + '%';
                whereClauses.add('(AEHC_Publication__r.AEHC_Application__r.Name LIKE :searchKey OR AEHC_Publication__r.Name LIKE :searchKey)');
            }
            
            String soql = 'SELECT AEHC_Publication__c,AEHC_Publication__r.Id, AEHC_Frequency__c, AEHC_Publication__r.AEHC_Application__r.Name, AEHC_Environment__c, AEHC_Publication__r.Name, LastModifiedDate FROM AEHC_Asset__c ' +
                (whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ')) + ' ORDER BY AEHC_Publication__r.Name ASC LIMIT :limitSize OFFSET :offsetSize';
            
            // Step 1: Fetch publications-Versions
            List<AEHC_Asset__c> publicationsVersions = Database.query(soql);
            
            // Step 2: Collect Publication Ids
            Set<Id> pubIds = new Set<Id>();
            for (AEHC_Asset__c pubVer : publicationsVersions) pubIds.add(pubVer.AEHC_Publication__r.Id);
            
            // Step 3: Fetch Schema (Frequency): Since we are querying Version records for pubs, Fequency itself is queried.
            
            // Step 4: Map latest schema per publication: Since we are querying Version records for pubs, Fequency itself is queried.
            
            // Deduplicate by Publication
            Map<Id, AEHC_Asset__c> uniquePublications = new Map<Id, AEHC_Asset__c>();

            for (AEHC_Asset__c pubVer : publicationsVersions) {
                 // First record wins because query is ordered DESC
                if (!uniquePublications.containsKey(pubVer.AEHC_Publication__c)) {
                        uniquePublications.put(pubVer.AEHC_Publication__c, pubVer);
                }
            }

            // Build response
            results = new List<ResponseClass>();

            for (AEHC_Asset__c pubVer : uniquePublications.values()) {

                AEHC_Asset__c a = pubVer.AEHC_Publication__r;

                ResponseClass dto = new ResponseClass();
                dto.id = a.Id;
                dto.application = a.AEHC_Application__r.Name;
                dto.publication = a.Name;
                dto.lastUpdated = pubVer.LastModifiedDate;

                dto.schedule = String.isBlank(pubVer.AEHC_Frequency__c) ? 'Not Scheduled' : pubVer.AEHC_Frequency__c;

                results.add(dto);
            }  
        } 
        return results;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<String> fetchApplicationFilters() {
        List<String> apps = new List<String>();
        
        for (AggregateResult ar : [
            SELECT Name
            FROM AEHC_Asset__c
            WHERE Name != null
            AND RecordType.DeveloperName = 'AEHC_Application'
            GROUP BY Name
            ORDER BY Name
        ]) {
            apps.add((String) ar.get('Name'));
        }
        
        return apps;
    }
    
    @AuraEnabled
    public static Map<String, Object> getFilters() {
        Map<String, Object> response = new Map<String, Object>();
        try {
            Map<String, Object> data = new Map<String, Object>();
            data.put('Environment', AEHC_Utility.getPicklistValues('AEHC_Asset__c', 'AEHC_Environment__c'));
            
            response.put('status', 200);
            response.put('data', data);
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.getAssetMemberRoles', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
}