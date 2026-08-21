@IsTest
private class AEHC_CustomListViewControllerTest {

    private static final String BUSINESS_OWNER = 'Business Owner';
    private static final String DEVELOPER = 'Developer';

    @TestSetup
    static void setupData() {

        // Create test user
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = p.Id,
            Username = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;

        /*
         * Retrieve Record Types
         * Replace DeveloperName values if different in your org.
         */
        Id rtId = Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Application') 
                .getRecordTypeId();
        Id rtpubId = Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Publication') 
                .getRecordTypeId();
        
        Id dataPublicationRT = Schema.SObjectType.Subscription__c
                .getRecordTypeInfosByDeveloperName()
                .get('Data_Publication') 
                .getRecordTypeId();
        
        AEHC_Asset__c asset1 = new AEHC_Asset__c(
            Name = 'MainAsset',
			RecordTypeId = rtId
          );
        insert asset1; 

        // Publication Asset
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = 'Test Publication',
            AEHC_Application__c = asset1.Id,
            RecordTypeId = rtId,
            //RecordTypeId = publicationRT.Id,
            AEHC_Publication_Type__c = 'Full',
            AEHC_Publication_Id__c = 'PUB001',
            AEHC_Environment__c = 'DEV'
        );
        insert publication;
        
        AEHC_Asset__c publication2 = new AEHC_Asset__c(
            Name = 'Test Publication 2',
            RecordTypeId = rtpubId,
            AEHC_Publication_Type__c = 'Full',
            AEHC_Publication_Id__c = 'PUB002',
            AEHC_Environment__c = 'DEV'
        );
        insert publication2;

        // Consuming Application
        AEHC_Asset__c application = new AEHC_Asset__c(
            Name = 'Test Application'
        );
        insert application;

        // Asset Member (Publication Access)
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = application.Id,
            AEHC_User__c = testUser.Id,
            AEHC_Role__c = BUSINESS_OWNER
        );

        // Asset Member for publication query
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = publication.Id,
            AEHC_User__c = testUser.Id,
            AEHC_Role__c = DEVELOPER
        );

        // Subscription created by test user
        System.runAs(testUser) {

            Subscription__c sub1 = new Subscription__c(
                RecordTypeId = dataPublicationRT,
                AEHC_Publication_ID__c = publication2.Id,
                AEHC_Consumming_Application__c = application.Id,
                Status__c = 'Active'
            );

            insert sub1;
        }
    }

    @IsTest
    static void testGetMyPublications() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        System.runAs(testUser) {

            Test.startTest();

            List<AEHC_Asset__c> results =
                AEHC_CustomListViewController.getMyPublications();

            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result should not be null'
            );
        }
    }

    @IsTest
    static void testGetMySubscriptions_MySubscriptions() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        System.runAs(testUser) {

            Test.startTest();

            List<Subscription__c> results =
                AEHC_CustomListViewController.getMySubscriptions(
                    'My Subscriptions'
                );

            Test.stopTest();

            System.assertEquals(
                1,
                results.size(),
                'User-created subscription should be returned'
            );
        }
    }

    @IsTest
    static void testGetMySubscriptions_MyApplicationsSubscriptions() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        System.runAs(testUser) {

            Test.startTest();

            List<Subscription__c> results =
                AEHC_CustomListViewController.getMySubscriptions(
                    'My Applications Subscriptions'
                );

            Test.stopTest();

            System.assertEquals(
                1,
                results.size(),
                'Subscription linked to BO application should be returned'
            );
        }
    }
    
    @IsTest
    static void testGetMySubscriptions_MyApplicationsSubscriptions_Failure() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        System.runAs(testUser) {

            Test.startTest();

            List<Subscription__c> results =
                AEHC_CustomListViewController.getMySubscriptions(null);
				AEHC_CustomListViewController.getMySubscriptions('');
            Test.stopTest();

            System.assertEquals(
                1,
                results.size(),
                'Subscription linked to BO application should be returned'
            );
        }
    }

    @IsTest
    static void testGetMySubscriptions_UnknownView() {

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'tuser'
            LIMIT 1
        ];

        System.runAs(testUser) {

            Test.startTest();

            List<Subscription__c> results =
                AEHC_CustomListViewController.getMySubscriptions(
                    'Random View'
                );

            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Method should return records without throwing exception'
            );
        }
    }

    @IsTest
    static void testGetMyPublications_Exception() {
        // Turn on the exception flag
        AEHC_CustomListViewController.forceException = true;
        
        Test.startTest();
        try {
            AEHC_CustomListViewController.getMyPublications();
            System.assert(false, 'An AuraHandledException should have been thrown.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'The exception was successfully caught by the catch block.');
        }
        Test.stopTest();
    }
 
    @IsTest
    static void testGetMySubscriptions_Exception() {
        // Turn on the exception flag
        AEHC_CustomListViewController.forceException = true;
        
        Test.startTest();
        try {
            AEHC_CustomListViewController.getMySubscriptions('My Subscriptions');
            System.assert(false, 'An AuraHandledException should have been thrown.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'The exception was successfully caught by the catch block.');
        }
        Test.stopTest();
    }
}