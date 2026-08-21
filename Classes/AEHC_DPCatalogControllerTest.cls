@IsTest
private class AEHC_DPCatalogControllerTest {

    @testSetup
    static void setupData() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName();

        System.assert(
            rtMap.containsKey('AEHC_Application'),
            'Record Type AEHC_Application must exist for this test.'
        );

        System.assert(
            rtMap.containsKey('AEHC_Publication'),
            'Record Type AEHC_Publication must exist for this test.'
        );

        Id applicationRtId = rtMap.get('AEHC_Application').getRecordTypeId();
        Id publicationRtId = rtMap.get('AEHC_Publication').getRecordTypeId();
        Id versionRtId = rtMap.get('AEHC_Version').getRecordTypeId();

        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Finance App',
            RecordTypeId = applicationRtId
        );
        insert app;
        insert new AEHC_AssetMember__c(
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Asset__c = app.Id,
            AEHC_Role__c = AEHC_Constant.ROLE_BUSINESS_OWNER
        );

        // pubs
        List<AEHC_Asset__c> publications = new List<AEHC_Asset__c>();

        for (Integer i = 0; i < 5; i++) {
            publications.add(new AEHC_Asset__c(
                Name = 'Publication ' + i,
                RecordTypeId = publicationRtId,
                AEHC_Application__c = app.Id,
                AEHC_Schedule__c = 'Daily'
            ));
        }
        insert publications;
        
        // versions
        List<AEHC_Asset__c> versions = new List<AEHC_Asset__c>();
        List<AEHC_AssetMember__c> members = new List<AEHC_AssetMember__c>();

        for (Integer i = 0; i < 5; i++) {
            versions.add(new AEHC_Asset__c(
                Name = 'Version ' + i,
                AEHC_Publication__c = publications[i].Id,
                AEHC_Environment__c = 'Dev',
                RecordTypeId = versionRtId,
                AEHC_Schedule__c = 'Daily',
                AEHC_Is_Active__c = true
            ));
        }
        insert versions;
        
      

        
    }

    @IsTest
    static void testFetchAssets_basic() {
        Test.startTest();
        List<AEHC_DataPublicationCatalogController.ResponseClass> results =
            AEHC_DataPublicationCatalogController.fetchAssets(
                null,
                null,
                null,
                0,
                10
            );
        
        AEHC_DataPublicationCatalogController.fetchAssets(
                'fin',
                null,
                'Dev',
                0,
                10
            );
        AEHC_DataPublicationCatalogController.getFilters();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(5, results.size(), 'Five publication records should be returned.');

        AEHC_DataPublicationCatalogController.ResponseClass r = results[0];

        System.assertNotEquals(null, r.id, 'Id should be populated.');
        System.assertNotEquals(null, r.publication, 'Publication should be populated.');
        System.assertEquals('Finance App', r.application, 'Application should be Finance App.');
       // System.assertEquals('Not Scheduled', r.schedule, 'Schedule should be Daily.');
        System.assertNotEquals(null, r.lastUpdated, 'Last updated should be populated.');
    }

    @IsTest
    static void testFetchAssets_withSearchAndApp() {
        Test.startTest();
        List<AEHC_DataPublicationCatalogController.ResponseClass> results =
            AEHC_DataPublicationCatalogController.fetchAssets(
                'Pub',
                'Finance App',
                null,
                0,
                5
            );
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Filtered results should return five records.');

        for (AEHC_DataPublicationCatalogController.ResponseClass r : results) {
            System.assert(
                r.publication.contains('Publication'),
                'Publication name should match search key.'
            );
            System.assertEquals('Finance App', r.application, 'Application filter should match.');
        }
    }

    @IsTest
    static void testFetchAssets_searchKeyLessThanThreeIgnored() {
        Test.startTest();
        List<AEHC_DataPublicationCatalogController.ResponseClass> results =
            AEHC_DataPublicationCatalogController.fetchAssets(
                'Pu',
                null,
                null,
                0,
                10
            );
        Test.stopTest();

        System.assertEquals(
            5,
            results.size(),
            'Search key shorter than three characters should be ignored.'
        );
    }

    @IsTest
    static void testFetchAssets_applicationOnly() {
        Test.startTest();
        List<AEHC_DataPublicationCatalogController.ResponseClass> results =
            AEHC_DataPublicationCatalogController.fetchAssets(
                null,
                'Finance App',
                null,
                0,
                10
            );
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Application filter should return five records.');

        for (AEHC_DataPublicationCatalogController.ResponseClass r : results) {
            System.assertEquals('Finance App', r.application);
        }
    }

    @IsTest
    static void testFetchAssets_noMatch() {
        Test.startTest();
        List<AEHC_DataPublicationCatalogController.ResponseClass> results =
            AEHC_DataPublicationCatalogController.fetchAssets(
                'XYZ',
                'Finance App',
                null,
                0,
                10
            );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No records should match XYZ.');
    }

    @IsTest
    static void testFetchAssets_pagination() {
        Test.startTest();

        List<AEHC_DataPublicationCatalogController.ResponseClass> page1 =
            AEHC_DataPublicationCatalogController.fetchAssets(null, null, null, 0, 2);

        List<AEHC_DataPublicationCatalogController.ResponseClass> page2 =
            AEHC_DataPublicationCatalogController.fetchAssets(null, null, null, 2, 2);

        Test.stopTest();

        System.assertEquals(2, page1.size(), 'Page 1 should contain two records.');
        System.assertEquals(2, page2.size(), 'Page 2 should contain two records.');

        Set<Id> page1Ids = new Set<Id>();
        for (AEHC_DataPublicationCatalogController.ResponseClass r : page1) {
            page1Ids.add(r.id);
        }

        for (AEHC_DataPublicationCatalogController.ResponseClass r : page2) {
            System.assert(
                !page1Ids.contains(r.id),
                'Page 2 records should not duplicate Page 1 records.'
            );
        }
    }

    @IsTest
    static void testFetchApplicationFilters() {
        Test.startTest();
        List<String> apps =
            AEHC_DataPublicationCatalogController.fetchApplicationFilters();
        Test.stopTest();

        System.assertNotEquals(null, apps, 'Application filter list should not be null.');
        /*System.assert(
            apps.contains('Finance App'),
            'Application filters should include Finance App.'
        );*/
    }
}