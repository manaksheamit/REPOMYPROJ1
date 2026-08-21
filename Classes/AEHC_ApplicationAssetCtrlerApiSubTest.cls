@IsTest
private class AEHC_ApplicationAssetCtrlerApiSubTest {

    @TestSetup
    static void createTestData() {

        Id applicationRtId = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        AEHC_Asset__c applicationAsset = new AEHC_Asset__c(
            Name = 'Test Application',
            RecordTypeId = applicationRtId
        );
        insert applicationAsset;

        AEHC_AssetMember__c assetMember = new AEHC_AssetMember__c(
            AEHC_User__c = testUser.Id,
            AEHC_Asset__c = applicationAsset.Id
           // AEHC_Asset_Name__c = 'Test Application'
        );
        insert assetMember;
    }

    @IsTest
    static void testGetApplicationAssets_ReturnsResults() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        Test.startTest();

        List<AEHC_ApplicationAssetControllerApiSub.AssetOption> results =
            AEHC_ApplicationAssetControllerApiSub.getApplicationAssets(
                testUser.Id
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Application', results[0].label);
        System.assertNotEquals(null, results[0].value);
    }

    @IsTest
    static void testGetApplicationAssets_NoResults() {

        User noAssetUser = new User(
            FirstName = 'NoAsset',
            LastName = 'User',
            Alias = 'nausr',
            Email = 'noasset@test.com',
            Username = 'noasset' + System.currentTimeMillis() + '@test.com',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert noAssetUser;

        Test.startTest();

        List<AEHC_ApplicationAssetControllerApiSub.AssetOption> results =
            AEHC_ApplicationAssetControllerApiSub.getApplicationAssets(
                noAssetUser.Id
            );

        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testAssetOptionConstructor() {

        AEHC_ApplicationAssetControllerApiSub.AssetOption option =
            new AEHC_ApplicationAssetControllerApiSub.AssetOption(
                'AssetId123',
                'My Application'
            );

        System.assertEquals('AssetId123', option.value);
        System.assertEquals('My Application', option.label);
    }
}