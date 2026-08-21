@IsTest
private class AEHC_RITMValidator_Test {

    @TestSetup
    static void createTestData() {

        Id assetRtId = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();

        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = 'Test Asset',
            RecordTypeId = assetRtId
        );
        insert asset;

        Id subscriptionRtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        Subscription__c sub = new Subscription__c(
            RecordTypeId = subscriptionRtId,
            AEHC_Consumming_Application__c = asset.Id,
            AEHC_Hosting_Location__c = 'AWS',
            AEHC_SNow_Status__c = 'Open',
            AEHC_SNow_Request__c = 'REQ001',
            AEHC_Intra_Request__c = 'INTRA001'
        );

        insert sub;
    }

    @IsTest
    static void testSubscriptionExists() {

        AEHC_Asset__c asset = [
            SELECT Id
            FROM AEHC_Asset__c
            LIMIT 1
        ];

        AEHC_RITMValidator.Input inputRec = new AEHC_RITMValidator.Input();
        inputRec.consumingApplicationId = asset.Id;
        inputRec.hostingLocation = 'AWS';

        Test.startTest();

        List<AEHC_RITMValidator.Output> results =
            AEHC_RITMValidator.checkSubscriptionExists(
                new List<AEHC_RITMValidator.Input>{ inputRec }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].recordExists);
        System.assertEquals('Open', results[0].serviceNowStatus);
        System.assertEquals('REQ001', results[0].serviceNowRequest);
        System.assertEquals('INTRA001', results[0].intraRequest);
    }

    @IsTest
    static void testSubscriptionDoesNotExist() {

        AEHC_Asset__c asset = [
            SELECT Id
            FROM AEHC_Asset__c
            LIMIT 1
        ];

        AEHC_RITMValidator.Input inputRec = new AEHC_RITMValidator.Input();
        inputRec.consumingApplicationId = asset.Id;
        inputRec.hostingLocation = 'AZURE';

        Test.startTest();

        List<AEHC_RITMValidator.Output> results =
            AEHC_RITMValidator.checkSubscriptionExists(
                new List<AEHC_RITMValidator.Input>{ inputRec }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].recordExists);
        System.assertEquals(null, results[0].serviceNowStatus);
        System.assertEquals(null, results[0].serviceNowRequest);
        System.assertEquals(null, results[0].intraRequest);
    }
}