/*@description This test class covers test scenerios for AEHC_SubscriptionTriggerHandler.
* @author Himanshu Singh
* @version 1.0
*/
@isTest
private class AEHC_SubscriptionTriggerHandlerTest {
    
    
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Subscription__c sub = new Subscription__c(
            AEHC_Environment__c = 'Dev'
        );
        insert sub;
        
        // Application RecordType
        RecordType appRt = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = 'AEHC_Asset__c' 
            AND DeveloperName = 'AEHC_Application'
            LIMIT 1
        ];
        
        // Application Asset
        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = 'App1', 
            RecordTypeId = appRt.Id,
            AEHC_Subscription_Request__c = sub.Id
        );
        insert asset;
        
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
        
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        AEHC_AssetMember__c am1 = new AEHC_AssetMember__c(
            AEHC_Asset__c = asset.Id,
            AEHC_User__c = u.Id,
            AEHC_Role__c = 'Business Owner'
        );
        
        AEHC_AssetMember__c am2 = new AEHC_AssetMember__c(
            AEHC_CommunityAsset__c = commAsset.Id,
            AEHC_User__c = u.Id,
            AEHC_Role__c = 'Admin'
        );
        
        insert new List<AEHC_AssetMember__c>{am1, am2};
    }
    
    
    @isTest
    static void test_withAsset() {
        AEHC_Asset__c asset = [SELECT Id FROM AEHC_Asset__c WHERE Name = 'App1' LIMIT 1];
        
        Subscription__c sub = new Subscription__c(
            AEHC_Consumming_Application__c = asset.Id
        );
        
        insert sub;
    }
    
    
    @isTest
    static void test_withCommunityAsset() {
        ms_aeh__CommunityAsset__c asset = [SELECT Id FROM ms_aeh__CommunityAsset__c LIMIT 1];
        
        Subscription__c sub = new Subscription__c(
            Community_Asset__c = asset.Id
        );
        
        insert sub;
    }
    @IsTest
    static void testAfterInsert_CreateAccountAndUpdateSubscription() {

        // Create Application Asset without Account
        AEHC_Asset__c appAsset = new AEHC_Asset__c(
            Name = 'Test Application'
        );
        insert appAsset;

        // Create Subscription
        Subscription__c sub = new Subscription__c(
            
            AEHC_Application_Name__c = appAsset.Id
        );
        insert sub;

        Test.startTest();

        AEHC_SubscriptionTriggerHandler.afterInsert(
            new List<Subscription__c>{sub}
        );

        Test.stopTest();

        // Verify Account created
        Account createdAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'Test Application'
            LIMIT 1
        ];

        System.assertNotEquals(
            null,
            createdAccount.Id,
            'Account should be created'
        );

        // Verify Asset updated with Account
        appAsset = [
            SELECT Id, AEHC_Account__c
            FROM AEHC_Asset__c
            WHERE Id = :appAsset.Id
        ];

        System.assertEquals(
            createdAccount.Id,
            appAsset.AEHC_Account__c,
            'Asset should reference created account'
        );

        // Verify Subscription updated
        sub = [
            SELECT Id, AEHC_Group_Account__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];

        System.assertEquals(
            createdAccount.Id,
            sub.AEHC_Group_Account__c,
            'Subscription should reference created account'
        );
    }
    
    @IsTest
static void testCreateACRFromSecurityArchitect() {

    // Account
    Account acct = new Account(
        Name = 'Test Account'
    );
    insert acct;

    // Contact used by Security Architect
    Contact con = new Contact(
        LastName = 'Security Architect',
        AccountId = acct.Id
    );
    insert con;

    // AEHC User
    User aehcuser = AEHC_TestDataFactory.create_ExternalUser('external.user@test.com');

    // Community Asset
    ms_aeh__CommunityAsset__c asset =  AEHC_TestDataFactory.create_CommunityAsset('API', True);

    // Asset Member with Security Architect role
    AEHC_AssetMember__c assetMember = new AEHC_AssetMember__c(
        //AEHC_Asset__c = asset.Id,
        AEHC_User__c = aehcUser.Id,
        AEHC_Role__c = 'Security Architect'
    );
    insert assetMember;

    // Subscription
    Subscription__c oldSub = new Subscription__c(
        AEHC_Environment_Name__c = 'PROD',
        Status__c = 'Pending Asset Owner Review',
        AEHC_AssetType__c = 'API',
        Community_Asset__c = asset.Id
    );
    

    Subscription__c sub = new Subscription__c(
        AEHC_Environment_Name__c = 'PROD',
        Status__c = 'Pending Security Review',
        AEHC_AssetType__c = 'API',
        Community_Asset__c = asset.Id
    );
    insert sub;

    // Query relationship fields required by handler
    sub = [
        SELECT Id,
               Status__c,
               AEHC_Environment_Name__c,
               AEHC_AssetType__c,
               Community_Asset__c,
               Community_Asset__r.AEHC_Account__c
        FROM Subscription__c
        WHERE Id = :sub.Id
    ];

    Subscription__c oldVersion = sub.clone(false, true, false, false);
    oldVersion.Status__c = 'Pending Asset Owner Review';

    Map<Id, Subscription__c> oldMap =
        new Map<Id, Subscription__c>{
            sub.Id => oldVersion
        };

    Test.startTest();

    AEHC_SubscriptionTriggerHandler.createAccountContactRelationship(
        new List<Subscription__c>{sub},
        oldMap
    );

    Test.stopTest();

   /* List<AccountContactRelation> acrs = [
        SELECT Id,
               AccountId,
               ContactId,
               IsActive
        FROM AccountContactRelation
        WHERE AccountId = :acct.Id
        AND ContactId = :con.Id
    ];*/

    /*System.assertEquals(
        1,
        acrs.size(),
        'ACR should be created'
    );

    System.assertEquals(
        true,
        acrs[0].IsActive
    );*/
}
    @IsTest
static void testCreateBusinessOwnerACR() {

    // Account
    Account acct = new Account(
        Name = 'Test Account'
    );
    insert acct;

    // Contact
    Contact con = new Contact(
        LastName = 'Business Owner',
        AccountId = acct.Id
    );
    insert con;

    // External User linked to Contact
    User aehcUser = AEHC_TestDataFactory.create_ExternalUser(
        'business.owner@test.com'
    );

    // Update contact if needed by your org setup
   /* con.AEHC_User_ID__c = aehcUser.Id; // remove if not applicable
    update con;*/

    // Community Asset
    ms_aeh__CommunityAsset__c asset =
        AEHC_TestDataFactory.create_CommunityAsset('Graph', true);

    asset.AEHC_Account__c = acct.Id;
    update asset;

    // Consuming Application Asset
    AEHC_Asset__c consumingApp = new AEHC_Asset__c(
        Name = 'Test Consuming App'
    );
    insert consumingApp;

    // Business Owner Asset Member
    AEHC_AssetMember__c assetMember =
        new AEHC_AssetMember__c(
            AEHC_Asset__c = consumingApp.Id,
            AEHC_User__c = aehcUser.Id,
            AEHC_Role__c = 'Business Owner'
        );
    insert assetMember;

    // API Asset Record Type
    Id apiAssetRtId =
        Schema.SObjectType.Subscription__c
        .getRecordTypeInfosByDeveloperName()
        .get('API_Asset')
        .getRecordTypeId();

    // Subscription meeting criteria
    Subscription__c sub = new Subscription__c(
        Status__c = 'Pending Subscriber Business Owner',
        AEHC_AssetType__c = 'graph',
        RecordTypeId = apiAssetRtId,
        Community_Asset__c = asset.Id,
        AEHC_Consumming_Application__c = consumingApp.Id
    );
    insert sub;

    sub = [
        SELECT Id,
               Status__c,
               AEHC_AssetType__c,
               RecordTypeId,
               Community_Asset__c,
               AEHC_Consumming_Application__c,
               Community_Asset__r.AEHC_Account__c
        FROM Subscription__c
        WHERE Id = :sub.Id
    ];

    Test.startTest();

    AEHC_SubscriptionTriggerHandler.createBusinessOwnerACR(
        new List<Subscription__c>{ sub }
    );

    Test.stopTest();

    // Verify Account Contact Relation
   /* List<AccountContactRelation> acrs = [
        SELECT Id,
               AccountId,
               ContactId,
               IsActive
        FROM AccountContactRelation
        WHERE AccountId = :acct.Id
    ];

    System.assertEquals(
        1,
        acrs.size(),
        'Business Owner ACR should be created'
    );

    System.assertEquals(
        true,
        acrs[0].IsActive,
        'ACR should be active'
    );

    // Verify Account Share
    List<AccountShare> shares = [
        SELECT Id,
               AccountId
        FROM AccountShare
        WHERE AccountId = :acct.Id
    ];

    System.assert(
        shares.size() > 0,
        'Account Share should be created'
    );*/
}
    
}