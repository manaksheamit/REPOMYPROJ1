public without sharing class AEHC_ApplicationAssetControllerApiSub {

@AuraEnabled(cacheable=true)
public static List<AssetOption> getApplicationAssets(string userID) {

    Id applicationRtId = Schema.SObjectType.AEHC_Asset__c
        .getRecordTypeInfosByDeveloperName()
        .get('AEHC_Application')
        .getRecordTypeId();

    List<AssetOption> options = new List<AssetOption>();

    for (AEHC_AssetMember__c asset : [
        SELECT AEHC_Asset__c,AEHC_Asset_Name__c,AEHC_Asset__r.Name 
        FROM AEHC_AssetMember__c 
        WHERE AEHC_User__c = :userID AND AEHC_Asset__c != null AND AEHC_Asset__r.RecordTypeId = :applicationRtId
    ]) {
        options.add(new AssetOption(asset.AEHC_Asset__c, asset.AEHC_Asset_Name__c));
    }

    return options;
    }
    public class AssetOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public AssetOption(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}