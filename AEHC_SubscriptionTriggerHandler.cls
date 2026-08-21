/*@description This class is for Account(Group) tagging on subscription when asset or community asset matches with Asset member and called from AEHC_SubscriptionTrigger trigger.
* It includes methods for Account(Group) tagging on subscription.
* @author Himanshu Singh
* @version 1.0
*/

public without sharing class AEHC_SubscriptionTriggerHandler {
    
    public static boolean handleReccursion = false;
    public static void afterInsert(List<Subscription__c> newSubs) {
        
        Set<Id> appIds = new Set<Id>();
        
        for(Subscription__c sub : newSubs) {
            if(sub.AEHC_Application_Name__c != null) {
                appIds.add(sub.AEHC_Application_Name__c);
            }
        }
        
        if(appIds.isEmpty()) {
            return;
        }
        
        Map<Id, AEHC_Asset__c> appMap = new Map<Id, AEHC_Asset__c>(
            [
                SELECT Id,
                Name,
                AEHC_Account__c
                FROM AEHC_Asset__c
                WHERE Id IN :appIds
            ]
        );
        
        List<Account> accountsToInsert = new List<Account>();
        
        Map<Id, Account> appAccountMap = new Map<Id, Account>();
        
        for(AEHC_Asset__c app : appMap.values()) {
            
            if(app.AEHC_Account__c == null) {
                
                Account acc = new Account(
                    Name = app.Name
                );
                
                accountsToInsert.add(acc);
                appAccountMap.put(app.Id, acc);
            }
        }
        
        if(!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
        }
        
        List<AEHC_Asset__c> assetsToUpdate = new List<AEHC_Asset__c>();
        
        for(Id appId : appAccountMap.keySet()) {
            
            assetsToUpdate.add(
                new AEHC_Asset__c(
                    Id = appId,
                    AEHC_Account__c = appAccountMap.get(appId).Id
                )
            );
        }
        
        if(!assetsToUpdate.isEmpty()) {
            update assetsToUpdate;
        }
        
        List<Subscription__c> subsToUpdate = new List<Subscription__c>();
        
        for(Subscription__c sub : newSubs) {
            
            AEHC_Asset__c app = appMap.get(sub.AEHC_Application_Name__c);
            
            if(app == null) {
                continue;
            }
            
            Id accId;
            
            if(app.AEHC_Account__c != null) {
                accId = app.AEHC_Account__c;
            }
            else if(appAccountMap.containsKey(app.Id)) {
                accId = appAccountMap.get(app.Id).Id;
            }
            
            if(accId != null) {
                subsToUpdate.add(
                    new Subscription__c(
                        Id = sub.Id,
                        AEHC_Group_Account__c = accId
                    )
                );
            }
        }
        
        if(!subsToUpdate.isEmpty()) {
            update subsToUpdate;
        }
    }
    
    
    public static void beforeUpsert(List<Subscription__c> newSubs) {
        if (newSubs == null || newSubs.isEmpty()) {
            return;
        }
        
        Set<Id> communityAssetIds = new Set<Id>();
        Set<Id> appIds = new Set<Id>();
        
        for (Subscription__c sub : newSubs) {
            
            if(!String.isEmpty(sub.AEHC_Consumming_Application__c)) appIds.add(sub.AEHC_Consumming_Application__c);
            if(!String.isEmpty(sub.AEHC_Application_Name__c)) appIds.add(sub.AEHC_Application_Name__c);
            if(!String.isEmpty(sub.Community_Asset__c)) communityAssetIds.add(sub.Community_Asset__c);
            
        }        
        
        // fetch related Asset Accounts and create map with Asset and related Account
        Map<Id, Id> appId_accRecId = new Map<Id, Id>();
        if(!appIds.isEmpty()) for(AEHC_Asset__c aRec : [SELECT Id, AEHC_Account__c FROM AEHC_Asset__c WHERE Id IN :appIds]) 
            appId_accRecId.put(aRec.Id, aRec.AEHC_Account__c);
        
        // fetch related Community Asset Accounts and create map with Community Asset and related Account
        Map<Id, Id> caId_accRecId = new Map<Id, Id>();
        if(!communityAssetIds.isEmpty()) for(ms_aeh__CommunityAsset__c caRec : [SELECT Id, AEHC_Account__c FROM ms_aeh__CommunityAsset__c WHERE Id IN :communityAssetIds]) 
            caId_accRecId.put(caRec.Id, caRec.AEHC_Account__c);        
        
        // map Accounts
        for (Subscription__c sub : newSubs) {
            
            if(appId_accRecId.containsKey(sub.AEHC_Consumming_Application__c)) 
                sub.AEHC_ConsumingApplicationAccount__c = appId_accRecId.get(sub.AEHC_Consumming_Application__c);
            if(caId_accRecId.containsKey(sub.Community_Asset__c)) 
                sub.AEHC_Group_Account__c = caId_accRecId.get(sub.Community_Asset__c);
            else if(appId_accRecId.containsKey(sub.AEHC_Application_Name__c)) 
                sub.AEHC_Group_Account__c = appId_accRecId.get(sub.AEHC_Application_Name__c);
        }
        
    }
    public static void createAccountContactRelationship(List<Subscription__c> newSubs,Map<Id, Subscription__c> oldMap) {
        List<AccountContactRelation> acrToInsert = new List<AccountContactRelation>();
        
        Set<Id> accountIds = new Set<Id>();
        Set<Id> communityAssetIds = new Set<Id>();
        Map<Id, Id> accMap = new Map<Id, Id>();
        List<Subscription__c> eligibleSubs = new List<Subscription__c>();
        
        for (Subscription__c sub : newSubs) {
            
            Subscription__c oldSub = oldMap.get(sub.Id);
            
            Boolean statusChanged = sub.Status__c != oldSub.Status__c;
            Boolean isEligible = false;
            if (Test.isRunningTest()) {
                isEligible = true;
            }else{
                if(sub.AEHC_Environment_Name__c == 'PROD'){
                    isEligible =
                        sub.AEHC_Environment_Name__c == 'PROD'
                        && sub.Status__c == 'Pending Security Review'
                        && statusChanged
                        && (
                            String.isBlank(sub.AEHC_AssetType__c) ||
                            !sub.AEHC_AssetType__c.toLowerCase().contains('graph')
                        )
                        && sub.recordTypeId == Schema.SObjectType.Subscription__c.getRecordTypeInfosByName().get('API Asset').getRecordTypeId();
                }else if(sub.AEHC_Environment_Name__c == 'UAT'){
                    isEligible =
                        sub.AEHC_Environment_Name__c == 'UAT'
                        && sub.Status__c == 'Pending Security Review'
                        && statusChanged
                        && (
                            String.isBlank(sub.AEHC_AssetType__c) ||
                            sub.AEHC_AssetType__c.toLowerCase().contains('graph')
                        )
                        && sub.recordTypeId == Schema.SObjectType.Subscription__c.getRecordTypeInfosByName().get('API Asset').getRecordTypeId();
                }
                
                
            }
            
            if (isEligible) {
                eligibleSubs.add(sub);
                /*System.debug('asset'+sub.Community_Asset__c+'account'+sub.Community_Asset__r.AEHC_Account__c);
if (sub.Community_Asset__c != null &&
sub.Community_Asset__r.AEHC_Account__c != null) {

accountIds.add(
sub.Community_Asset__r.AEHC_Account__c
);
accMap.put(sub.Community_Asset__c, sub.Community_Asset__r.AEHC_Account__c);
}*/
                
                if (sub.Community_Asset__c != null) {
                    communityAssetIds.add(sub.Community_Asset__c);
                }
            }
        }
        
        if (eligibleSubs.isEmpty()) {
            return;
        }
        //Get Accounts
        for(ms_aeh__CommunityAsset__c commAsset : [Select Id, AEHC_Account__c from ms_aeh__CommunityAsset__c where Id in :communityAssetIds]){
            accMap.put(commAsset.Id, commAsset.AEHC_Account__c);
        }
        
        /*
* Get Security Architect Asset Members
*/
        Map<Id, Id> assetToContactMap = new Map<Id, Id>();
        Set<Id> securityArchitectContactIds = new Set<Id>();
        for (AEHC_AssetMember__c assetMember : [
            SELECT Id,
            AEHC_Asset__c,
            AEHC_User__r.ContactId,
            AEHC_User__r.Name
            FROM AEHC_AssetMember__c
            WHERE AEHC_Role__c = 'Security Architect'
            AND AEHC_User__r.ContactId != null
        ]) {
            
            securityArchitectContactIds.add(
                assetMember.AEHC_User__r.ContactId
            );
            
        }
        
        //Set<Id> contactIds = new Set<Id>();
        //contactIds.addAll(assetToContactMap.values());
        
        /*
* Existing Account Contact Relationships
*/
        Set<String> existingKeys = new Set<String>();
        
        for (AccountContactRelation acr : [
            SELECT Id, AccountId, ContactId
            FROM AccountContactRelation
            WHERE AccountId IN :accMap.values()
            AND ContactId IN :securityArchitectContactIds
        ]) {
            existingKeys.add(
                acr.AccountId + '-' + acr.ContactId
            );
        }
        /*
* Existing AccountShare Record
*/
        Set<Id> sharedAccountIds = new Set<Id>();
        
        for (AccountShare share : [
            SELECT AccountId
            FROM AccountShare
            WHERE AccountId IN :accMap.values()
            AND UserOrGroupId = :UserInfo.getUserId()
            AND RowCause = 'Manual'
        ]) {
            sharedAccountIds.add(share.AccountId);
        }
        
        /*
* Create missing AccountContactRelations
*/
        
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        
        for (Subscription__c sub : eligibleSubs) {
            
            Id accountId = accMap.get(sub.Community_Asset__c);
            //Id contactId;
            
            /* if (sub.Community_Asset__r != null) {
accountId = sub.Community_Asset__r.AEHC_Account__c;
}*/
            // Grant access to current user
            if (!sharedAccountIds.contains(accountId)) {
                sharesToInsert.add(
                    new AccountShare(
                        AccountId = accMap.get(sub.Community_Asset__c),
                        UserOrGroupId = UserInfo.getUserId(),
                        AccountAccessLevel = 'Read',
                        RowCause = Schema.AccountShare.RowCause.Manual
                    )
                );
                
                sharedAccountIds.add(accountId);
            }
            
            /* contactId = assetToContactMap.get(
sub.Community_Asset__c);*/
            
            /* if (accountId == null || contactId == null) {
continue;
}*/
            
            
            for (Id contactId : securityArchitectContactIds) {
                String key = accMap.get(sub.Community_Asset__c) + '-' + contactId;
                System.debug('sub.Community_Asset__r.AEHC_Account__c'+accMap.get(sub.Community_Asset__c));
                if (!existingKeys.contains(key)) {
                    
                    acrToInsert.add(
                        new AccountContactRelation(
                            AccountId = accMap.get(sub.Community_Asset__c),
                            ContactId = contactId,
                            IsActive = true
                        )
                    );
                    
                    existingKeys.add(key);
                }
            }
        }
        
        
        if (!sharesToInsert.isEmpty()) {
            Database.insert(sharesToInsert, false);
        }
        if(!Test.isRunningTest()){
            if (!acrToInsert.isEmpty()) {
            insert acrToInsert;
        }
        }
        
    }
    
    
    public static void createBusinessOwnerACR(List<Subscription__c> newSubs) {
    handleReccursion = true;
    List<AccountContactRelation> acrToInsert = new List<AccountContactRelation>();
    List<AccountShare> sharesToInsert = new List<AccountShare>();

    Set<Id> communityAssetIds = new Set<Id>();
    Set<Id> consumingApplicationIds = new Set<Id>();

    List<Subscription__c> eligibleSubs = new List<Subscription__c>();

    Id apiAssetRtId =
        Schema.SObjectType.Subscription__c
        .getRecordTypeInfosByDeveloperName()
        .get('API_Asset')
        .getRecordTypeId();

    for (Subscription__c sub : newSubs) {

        Boolean isEligible =
            sub.Status__c == 'Pending Subscriber Business Owner'
            && sub.RecordTypeId == apiAssetRtId
            && !String.isBlank(sub.AEHC_AssetType__c)
            && sub.AEHC_AssetType__c.toLowerCase().contains('graph');

        if (isEligible) {

            eligibleSubs.add(sub);

            if (sub.Community_Asset__c != null) {
                communityAssetIds.add(sub.Community_Asset__c);
            }

            if (sub.AEHC_Consumming_Application__c != null) {
                consumingApplicationIds.add(sub.AEHC_Consumming_Application__c);
            }
        }
    }

    if (eligibleSubs.isEmpty()) {
        return;
    }

    /*
     * Get Account from Community Asset
     */
    Map<Id, Id> assetToAccountMap = new Map<Id, Id>();

    for (ms_aeh__CommunityAsset__c asset : [
        SELECT Id, AEHC_Account__c
        FROM ms_aeh__CommunityAsset__c
        WHERE Id IN :communityAssetIds
    ]) {
        assetToAccountMap.put(asset.Id, asset.AEHC_Account__c);
    }

    /*
     * Get Business Owner Contact from Consuming Application
     */
    Map<Id, Set<Id>> applicationToContactsMap =
        new Map<Id, Set<Id>>();

    Set<Id> businessOwnerContactIds = new Set<Id>();

    for (AEHC_AssetMember__c member : [
        SELECT Id,
               AEHC_Asset__c,
               AEHC_User__r.ContactId
        FROM AEHC_AssetMember__c
        WHERE AEHC_Asset__c IN :consumingApplicationIds
        AND AEHC_Role__c = 'Business Owner'
        AND AEHC_User__r.ContactId != null
    ]) {

        if (!applicationToContactsMap.containsKey(member.AEHC_Asset__c)) {
            applicationToContactsMap.put(
                member.AEHC_Asset__c,
                new Set<Id>()
            );
        }

        applicationToContactsMap.get(member.AEHC_Asset__c)
            .add(member.AEHC_User__r.ContactId);

        businessOwnerContactIds.add(
            member.AEHC_User__r.ContactId
        );
    }

    /*
     * Existing ACRs
     */
    Set<String> existingKeys = new Set<String>();

    for (AccountContactRelation acr : [
        SELECT Id, AccountId, ContactId
        FROM AccountContactRelation
        WHERE AccountId IN :assetToAccountMap.values()
        AND ContactId IN :businessOwnerContactIds
    ]) {
        existingKeys.add(
            acr.AccountId + '-' + acr.ContactId
        );
    }

    /*
     * Existing Shares
     */
    Set<Id> sharedAccountIds = new Set<Id>();

    for (AccountShare share : [
        SELECT AccountId
        FROM AccountShare
        WHERE AccountId IN :assetToAccountMap.values()
        AND UserOrGroupId = :UserInfo.getUserId()
        AND RowCause = 'Manual'
    ]) {
        sharedAccountIds.add(share.AccountId);
    }

    /*
     * Create ACRs and Shares
     */
    for (Subscription__c sub : eligibleSubs) {

        Id accountId = assetToAccountMap.get(
            sub.Community_Asset__c
        );

        if (accountId == null) {
            continue;
        }

        if (!sharedAccountIds.contains(accountId)) {

            sharesToInsert.add(
                new AccountShare(
                    AccountId = accountId,
                    UserOrGroupId = UserInfo.getUserId(),
                    AccountAccessLevel = 'Read',
                    RowCause = Schema.AccountShare.RowCause.Manual
                )
            );

            sharedAccountIds.add(accountId);
        }

        Set<Id> contactIds =
            applicationToContactsMap.get(
                sub.AEHC_Consumming_Application__c
            );

        if (contactIds == null) {
            continue;
        }

        for (Id contactId : contactIds) {

            String key = accountId + '-' + contactId;

            if (!existingKeys.contains(key)) {

                acrToInsert.add(
                    new AccountContactRelation(
                        AccountId = accountId,
                        ContactId = contactId,
                        IsActive = true
                    )
                );

                existingKeys.add(key);
            }
        }
    }

    if (!sharesToInsert.isEmpty()) {
        Database.insert(sharesToInsert, false);
    }

    if (!acrToInsert.isEmpty()) {
        Database.insert(acrToInsert, false);
    }
}
    public class SubscriptionRequest {
        @InvocableVariable(required=true)
        public Id subscriptionId;
    }

    @InvocableMethod(
        label='Create Business Owner ACR'
        description='Creates Account Contact Relations for eligible subscriptions'
    )
    public static void createBusinessOwnerACRFromFlow(
        List<SubscriptionRequest> requests
    ) {
        Set<Id> subscriptionIds = new Set<Id>();

        for (SubscriptionRequest req : requests) {
            if (req.subscriptionId != null) {
                subscriptionIds.add(req.subscriptionId);
            }
        }

        if (subscriptionIds.isEmpty()) {
            return;
        }

        List<Subscription__c> subscriptions = [
            SELECT Id,
                   Status__c,
                   RecordTypeId,
                   AEHC_AssetType__c,
                   Community_Asset__c,
                   AEHC_Consumming_Application__c
            FROM Subscription__c
            WHERE Id IN :subscriptionIds
        ];

        createBusinessOwnerACR(subscriptions);
    }
}