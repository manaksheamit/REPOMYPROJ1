/*@description This class is for ACR record creation when Asset Member created  and called from AEHC_AssetMemberACRTrigger trigger.
 * It includes methods for creating ACR record on the basis of account, contact and user tagger in asset member.
 * @author Himanshu Singh
 * @version 1.0
 */

public without sharing class AEHC_AssetMemberACRTriggerHandler {
    public static void assetMember(List<AEHC_AssetMember__c> newList){
        if (newList == null || newList.isEmpty()) return;
        
        // Collect User Ids from Asset Members (assumes AEHC_User__c is the lookup to User)
        Set<Id> userIds = new Set<Id>();
        for (AEHC_AssetMember__c am : newList) {
            if (am.AEHC_User__c != null) userIds.add(am.AEHC_User__c);
        }
        if (userIds.isEmpty()) return;
        
        // Query Users to get related ContactId and AccountId
        Map<Id, User> userId_UserRecs = new Map<Id, User>([SELECT Id, ContactId FROM User WHERE Id IN :userIds AND ContactId != null]);

        // collect Asset Ids and Communiet Assets for which Asset member records got created
        Set<Id> communityAssetIds = new Set<Id>();
        Set<Id> assetIds = new Set<Id>();
        for (AEHC_AssetMember__c am : newList) {
            if(!String.isEmpty(am.AEHC_CommunityAsset__c)) communityAssetIds.add(am.AEHC_CommunityAsset__c);
            if(!String.isEmpty(am.AEHC_Asset__c)) assetIds.add(am.AEHC_Asset__c);
        }
        
        // fetch related Community Asset Accounts and create map with Community Asset and related Account
        Map<Id, Id> caId_accRecId = new Map<Id, Id>();
        if(!communityAssetIds.isEmpty()) for(ms_aeh__CommunityAsset__c caRec : [SELECT Id, AEHC_Account__c FROM ms_aeh__CommunityAsset__c WHERE Id IN :communityAssetIds]) caId_accRecId.put(caRec.Id, caRec.AEHC_Account__c);
        
        // fetch related Asset Accounts and create map with Asset and related Account
        Map<Id, Id> assetId_accRecId = new Map<Id, Id>();
        if(!assetIds.isEmpty()) for(AEHC_Asset__c aRec : [SELECT Id, AEHC_Account__c FROM AEHC_Asset__c WHERE Id IN :assetIds]) assetId_accRecId.put(aRec.Id, aRec.AEHC_Account__c);
        
        // collect AccountId and Contact from Asset members
        Set<String> newAccId_ContactIds = new Set<String>();
        Set<Id> contactRecIds = new Set<Id>();
        Set<Id> accRecIds = new Set<Id>();
        for (AEHC_AssetMember__c am : newList) {
            if (am.AEHC_User__c == null) continue;
            if (!userId_UserRecs.containsKey(am.AEHC_User__c)) continue;
            
            Id contactId = userId_UserRecs.get(am.AEHC_User__c).ContactId;
            Id accountId;
            
            // check Community Asset map and get Account from Map
            if(caId_accRecId.containsKey(am.AEHC_CommunityAsset__c)) accountId = caId_accRecId.get(am.AEHC_CommunityAsset__c);
            
            // check Asset map and get Account from Map
            else if(assetId_accRecId.containsKey(am.AEHC_Asset__c)) accountId = assetId_accRecId.get(am.AEHC_Asset__c);
            
            if (accountId == null) continue;
            contactRecIds.add(contactId);
            accRecIds.add(accountId);
            newAccId_ContactIds.add(accountId + '-' + contactId);
        }
        
        if (newAccId_ContactIds.isEmpty()) return;
        
        // look for existing relationships
        Set<String> oldAccId_ContactIds = new Set<String>();
        if (!newAccId_ContactIds.isEmpty() && !contactRecIds.isEmpty()) {
            for (AccountContactRelation acr : [SELECT AccountId, ContactId FROM AccountContactRelation WHERE AccountId IN :accRecIds AND ContactId IN :contactRecIds]) 
                oldAccId_ContactIds.add(acr.AccountId + '-' + acr.ContactId);
        }
        
        // collect new record instances that need to be inserted
        List<AccountContactRelation> acrToInsert = new List<AccountContactRelation>();
        for(String key : newAccId_ContactIds) {
            if(oldAccId_ContactIds.contains(key)) continue;
            
            List<String> keyParts = key.split('-');
            acrToInsert.add(new AccountContactRelation(
                AccountId = keyParts[0],
                ContactId = keyParts[1]
                // Optionally set Role or IsPrimary if required, but not included by default
            ));
        }
        
        if(!acrToInsert.isEmpty()) AEHC_Utility.upsertRecs(acrToInsert);
    }
}