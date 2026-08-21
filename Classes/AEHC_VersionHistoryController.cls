public without sharing class AEHC_VersionHistoryController {
    
    public class VersionHistoryWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String environment;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public DateTime lastModifieddate;
        
        public VersionHistoryWrapper(AEHC_Asset__c asset) {
            this.name = asset.Name;
            this.environment = asset.AEHC_Environment__c;
            this.isActive = asset.AEHC_Is_Active__c;
            this.schemaVersion = asset.AEHC_Schema_Version__c;
            this.lastModifieddate = asset.LastModifiedDate;
            
        }
    }
    
    @AuraEnabled
    public static string getVersionId(String subId, String env, String version){
        List<AEHC_Asset__c> assetList = [SELECT Id FROM AEHC_Asset__c
                                         WHERE AEHC_Subscription_Request__c = :subId
                                         AND AEHC_Environment__c =:env 
                                         AND AEHC_Schema_Version__c =: version LIMIT 1];
        return assetList[0].Id;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<VersionHistoryWrapper> getVersionHistory(Id recordId) {
        
        List<VersionHistoryWrapper> result =
            new List<VersionHistoryWrapper>();
        
        if(recordId == null){
            return result;
        }
        
        String whereClause;
        
        if(recordId.getSObjectType() == Subscription__c.SObjectType) {
            
            whereClause =
                'AEHC_Subscription_Request__c = :recordId OR AEHC_Publication__c = :recordId';
            
        } else if(recordId.getSObjectType() == AEHC_Asset__c.SObjectType) {
            
            whereClause =
                'AEHC_Publication__c = :recordId AND AEHC_Is_Subscription__c = False';
            
        } else {
            return result;
        }
        
        List<AEHC_Asset__c> assetList = Database.query(
            'SELECT Id,' +
            ' Name,' +
            ' AEHC_Environment__c,' +
            ' AEHC_Is_Active__c,' +
            ' AEHC_Schema_Version__c,' +
            ' LastModifiedDate ' +
            'FROM AEHC_Asset__c ' +
            'WHERE ' + whereClause +
            ' ORDER BY AEHC_Environment__c DESC'
        );
        
        for(AEHC_Asset__c asset : assetList) {
            result.add(new VersionHistoryWrapper(asset));
        }
        
        return result;
    }
    
}