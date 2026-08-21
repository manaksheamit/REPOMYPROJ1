@IsTest
private class AEHCSubscriberControllerTest {

    
    @TestSetup
    static void setupData() {
    
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;
    
        // Get Record Type Ids
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName();
    
        Id publicationRT = rtMap.get('AEHC_Publication').getRecordTypeId();
        Id applicationRT = rtMap.get('AEHC_Application').getRecordTypeId();
        Id versionRT = rtMap.get('AEHC_Version').getRecordTypeId();
    
        // Create Application Asset
        AEHC_Asset__c application = new AEHC_Asset__c(
            Name = 'Consumer Application',
            RecordTypeId = applicationRT,
            AEHC_Account__c = acc.Id
        );
        insert application;
    
        // Create Publication Asset
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordTypeId = publicationRT,
            AEHC_Account__c = acc.Id
        );
        insert publication;
    
        // Create Subscription
        Subscription__c subscription = new Subscription__c(
            AEHC_Publication_ID__c = publication.Id,
            AEHC_Consumming_Application__c = application.Id
        );
        insert subscription;

        // Create Version Asset
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'Version 1',
            RecordTypeId = versionRT,
            AEHC_Account__c = acc.Id,
            AEHC_Publication__c = publication.Id,
            AEHC_Subscription_Request__c = subscription.Id,
            AEHC_Environment__c = 'DEV'
        );
        insert version;
	}

    @IsTest
    static void testGetSubscribers_NoSearch() {

        AEHC_Asset__c publication =
            [SELECT Id FROM AEHC_Asset__c where Name = 'Test Publication' LIMIT 1];

        Test.startTest();

        AEHCSubscriberController.SubscriberResponse response =
            AEHCSubscriberController.getSubscribers(
                publication.Id,
                'DEV',
                null,
                10,
                0
            );

        Test.stopTest();

    }

    @IsTest
    static void testGetSubscribers_WithSearch() {

        AEHC_Asset__c publication =
            [SELECT Id FROM AEHC_Asset__c where  Name = 'Test Publication' LIMIT 1];

        Test.startTest();

        AEHCSubscriberController.SubscriberResponse response =
            AEHCSubscriberController.getSubscribers(
                publication.Id,
                'DEV',
                'Consumer',
                10,
                0
            );

        Test.stopTest();

    }

    @IsTest
    static void testGetSubscribers_NoResults() {

        Test.startTest();

        AEHCSubscriberController.SubscriberResponse response =
            AEHCSubscriberController.getSubscribers(
                '001000000000000AAA',
                'DEV',
                null,
                10,
                0
            );

        Test.stopTest();

    }

    @IsTest
    static void testPagination() {

        AEHC_Asset__c publication =
            [SELECT Id FROM AEHC_Asset__c LIMIT 1];

        Test.startTest();

        AEHCSubscriberController.SubscriberResponse response =
            AEHCSubscriberController.getSubscribers(
                publication.Id,
                'DEV',
                null,
                10,
                10
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
    }

    @IsTest
    static void testWrapperCoverage() {

        AEHCSubscriberController.SubscriberWrapper wrapper =
            new AEHCSubscriberController.SubscriberWrapper();

        wrapper.application = 'Test App';
        wrapper.type = 'API';
        wrapper.environment = 'DEV';
        wrapper.approver = 'Test User';

        
    }
}