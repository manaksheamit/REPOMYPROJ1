/*@description This class is for Account(Group) creation and tagging to community asset and called from AEHC_GroupCreationOnCommunityAsset trigger.
 * It includes methods for Account(Group) creation on community Asset creation and tagging to community Asset.
 * @author Himanshu Singh
 * @version 1.0
 */
public without sharing class AEHC_GroupCreationCommunityAssetHandler {
    public static void accountCreation(List<ms_aeh__CommunityAsset__c> newList){
        if(newList == null || newList.isEmpty()) {
            return;
        }
        
        // Collect community names (using CommunityAsset.Name) filtering out null/blank values
        Set<String> communityNames = new Set<String>();
        for(ms_aeh__CommunityAsset__c ca : newList){
            communityNames.add(ca.Name);
        }

        if(communityNames.isEmpty()){
            return;
        }
        
        // Query existing Accounts by Name and build Name -> Id map
        Map<String, Id> accountMap = new Map<String, Id>();
        for(Account a : [SELECT Id, Name FROM Account WHERE Name IN :communityNames AND Name != null]){
            accountMap.put(a.Name, a.Id);
        }
        
        List<ms_aeh__CommunityAsset__c> assetUpdates = new List<ms_aeh__CommunityAsset__c>();
        List<AEHC_AccountCreationRequest__e> events = new List<AEHC_AccountCreationRequest__e>();

        for(ms_aeh__CommunityAsset__c asset : newList){                     

            if(accountMap.containsKey(asset.Name)){
                assetUpdates.add( new ms_aeh__CommunityAsset__c( Id = asset.Id,  AEHC_Account__c = accountMap.get(asset.Name) ) );

            } else {
                events.add(
                    new AEHC_AccountCreationRequest__e(
                        AEHC_AssetId__c = asset.Id,
                        AEHC_Asset_Name__c = asset.Name,
                        AEHCApplicationId__c=' ',
                        AEHC_SObjectType__c='CommunityAsset'
                    )
                );
            }
        } 

        if(!assetUpdates.isEmpty()){
            update assetUpdates;
        }

        if(!events.isEmpty()){           
            EventBus.publish(events);
        }        
    }
}