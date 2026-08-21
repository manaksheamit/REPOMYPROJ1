/*@description This test class covers test scenerios for AEHC_AssetMemberACRTriggerHandler.
* @author Himanshu Singh
* @version 1.0
*/
@isTest
private class AEHC_AssetMemberACRTriggerHandlerTest {
    
    @testSetup
    static void setupData() {
        User u = AEHC_TestDataFactory.create_ExternalUser('tes232323t@g.co');
        
        // Application Asset
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'App1', 
            RecordTypeId = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION)
        );
        insert app;
        
        // Community Asset
        ms_aeh__CommunityAsset__c commAsset = new ms_aeh__CommunityAsset__c(
            Name = 'Community1',
            ms_aeh__AssetId__c = 'A1',
            ms_aeh__AssetType__c = 'Type1',
            ms_aeh__GroupAssetId__c = 'GA1',
            ms_aeh__GroupId__c = 'G1',
            ms_aeh__Key__c = 'K1',
            ms_aeh__NetworkId__c = 'N1'
        );
        insert commAsset;
        
        Account acc = [SELECT Id FROM Account WHERE Name = 'Community1' LIMIT 1];
        
        insert new AccountContactRelation(
            AccountId = acc.Id,
            ContactId = [SELECT Id, ContactId FROM User WHERE Id = :u.Id LIMIT 1].ContactId
            // Optionally set Role or IsPrimary if required, but not included by default
        );
    }

      

    @isTest
    static void testACRCreation() {
        
        User u = [SELECT Id, ContactId FROM User WHERE username = 'tes232323t@g.co' LIMIT 1];
        ms_aeh__CommunityAsset__c caRec = [SELECT Id FROM ms_aeh__CommunityAsset__c LIMIT 1];
        AEHC_Asset__c appRec = [SELECT Id FROM AEHC_Asset__c LIMIT 1];

        // Create Asset Member record
        AEHC_AssetMember__c amCA = new AEHC_AssetMember__c(
            AEHC_User__c = u.Id,
            AEHC_Asset__c = appRec.Id
        );
        AEHC_AssetMember__c amApp = new AEHC_AssetMember__c(
            AEHC_User__c = u.Id,
            AEHC_CommunityAsset__c = caRec.Id
        );
        insert new List<AEHC_AssetMember__c>{amCA, amApp};
            
            System.debug([SELECT Id, Account.Name, Contact.Name FROM AccountContactRelation]);

    }
}