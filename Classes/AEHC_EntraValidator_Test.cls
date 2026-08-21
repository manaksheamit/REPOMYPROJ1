@IsTest
private class AEHC_EntraValidator_Test {

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
            AEHC_Environment_Name__c = 'DEV',
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

        AEHC_EntraValidator.Input inputRec = new AEHC_EntraValidator.Input();
        inputRec.consumingApplicationId = asset.Id;
        inputRec.environment = 'DEV';

        Test.startTest();

        List<AEHC_EntraValidator.Output> results =
            AEHC_EntraValidator.checkSubscriptionExists(
                new List<AEHC_EntraValidator.Input>{ inputRec }
            );

        Test.stopTest();
    }

    @IsTest
    static void testSubscriptionDoesNotExist() {

        AEHC_Asset__c asset = [
            SELECT Id
            FROM AEHC_Asset__c
            LIMIT 1
        ];

        AEHC_EntraValidator.Input inputRec = new AEHC_EntraValidator.Input();
        inputRec.consumingApplicationId = asset.Id;
        inputRec.environment = 'DEV';

        Test.startTest();

        List<AEHC_EntraValidator.Output> results =
            AEHC_EntraValidator.checkSubscriptionExists(
                new List<AEHC_EntraValidator.Input>{ inputRec }
            );

        Test.stopTest();
    }
}