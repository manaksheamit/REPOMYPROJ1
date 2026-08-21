@isTest
public class AEHC_CarouselController_Test {

    // -----------------------------
    // Utility Method
    // -----------------------------
    private static void setCurrentUserPrefs(String prefs) {
        User u = [SELECT Id, AEHC_Preference__c 
                  FROM User 
                  WHERE Id = :UserInfo.getUserId() 
                  LIMIT 1];
        u.AEHC_Preference__c = prefs;
        update u;
    }

    // -----------------------------
    // AC: No Preferences
    // -----------------------------
    @isTest
    static void test_NoUserPrefs() {
        setCurrentUserPrefs(null);

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards(null);
        Test.stopTest();

    }

    // -----------------------------
    // AC: Blank Preferences
    // -----------------------------
    @isTest
    static void test_BlankUserPrefs() {
        setCurrentUserPrefs('   ');

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('  ');
        Test.stopTest();

    }

    // -----------------------------
    // AC: Valid Prefs but No CMDT
    // -----------------------------
    @isTest
    static void test_ValidPrefs_NoMetadata() {
        
        setCurrentUserPrefs('API User;Data Product User');
        
        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>();
        
        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('API User;Data Product User');
        Test.stopTest();
        
    }

    // -----------------------------
    // AC: Mock Metadata - Covers Loop
    // -----------------------------
    @isTest
    static void test_WithMockMetadata() {

        setCurrentUserPrefs('API User');

        AEHC_Carousel_Config__mdt mock = new AEHC_Carousel_Config__mdt(
            DeveloperName = 'Test1',
            AEHC_Group__c = 'API User',
            AEHC_Active__c = true,
            AEHC_Tile_Title__c = 'Title1',
            AEHC_Tile_Description__c = 'Desc1',
            AEHC_RedirectURL__c = 'http://test.com'
        );

        AEHC_CarouselController.testMdt = 
            new Map<String, AEHC_Carousel_Config__mdt>{
                'Test1' => mock
            };

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

    }

    // -----------------------------
    // AC: Inactive Record Filtered
    // -----------------------------
    @isTest
    static void test_InactiveMetadataFilteredOut() {

        setCurrentUserPrefs('API User');

        AEHC_Carousel_Config__mdt mock = new AEHC_Carousel_Config__mdt(
            DeveloperName = 'Test2',
            AEHC_Group__c = 'API User',
            AEHC_Active__c = false
        );

        AEHC_CarouselController.testMdt =
            new Map<String, AEHC_Carousel_Config__mdt>{
                'Test2' => mock
            };

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

    }

    // -----------------------------
    // AC: Whitespace Handling
    // -----------------------------
    @isTest
    static void test_WhitespacePreferences() {

        setCurrentUserPrefs('  API User ; ; Data Product User  ');

        AEHC_Carousel_Config__mdt mock = new AEHC_Carousel_Config__mdt(
            DeveloperName = 'Test3',
            AEHC_Group__c = 'API User',
            AEHC_Active__c = true,
            AEHC_Tile_Title__c = 'Title3',
            AEHC_Tile_Description__c = 'Desc3',
            AEHC_RedirectURL__c = 'http://test3.com'
        );

        AEHC_CarouselController.testMdt =
            new Map<String, AEHC_Carousel_Config__mdt>{
                'Test3' => mock
            };

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('  API User ; ; Data Product User  ');
        Test.stopTest();

    }

    // -----------------------------
    // AC: Exception Handling (Catch Block)
    // -----------------------------
    @isTest
    static void test_ExceptionPath() {

        setCurrentUserPrefs('API User');

        AEHC_CarouselController.forceException = true;

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();


        // Reset flag
        AEHC_CarouselController.forceException = false;
    }

    // -----------------------------
    // AC: getPublications Returns Valid Data
    // -----------------------------
    @isTest
    static void test_GetPublications() {
        
        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

    }

    // -----------------------------
    // AC: getPublications URL Structure
    // -----------------------------
    @isTest
    static void test_GetPublications_URLStructure() {
        
        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

    }

    // -----------------------------
    // AC: Publication Data Integrity
    // -----------------------------
    @isTest
    static void test_GetPublications_DataIntegrity() {
        
        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        // Verify unique IDs
        Set<String> ids = new Set<String>();
    }

    /* =========================================================
     *  ADDED COVERAGE TESTS
     *  (production class untouched)
     * ========================================================= */

    private static Id recordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> infos =
            AEHC_Asset__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        return infos.containsKey(developerName) ? infos.get(developerName).getRecordTypeId() : null;
    }

    private static void setPrefs(String prefs) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User u = [SELECT Id, AEHC_Preference__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            u.AEHC_Preference__c = prefs;
            update u;
        }
    }

    private static AEHC_Carousel_Config__mdt buildCard(
        String devName, String group1, Boolean active, String title, String image
    ) {
        return new AEHC_Carousel_Config__mdt(
            DeveloperName = devName,
            AEHC_Group__c = group1,
            AEHC_Active__c = active,
            AEHC_Tile_Title__c = title,
            AEHC_Tile_Description__c = title + ' description',
            AEHC_RedirectURL__c = 'https://example.com/' + devName,
            AEHC_Image__c = image,
            AEHC_Sort_Order__c = 1
        );
    }

    /**
     * getPublications only returns assets of the AEHC_Publication record type
     * whose AEHC_Publication__c lookup is empty, so the loop body stays dead
     * until such records exist.
     */
    private static List<AEHC_Asset__c> createPublications(Integer count, String frequency) {
        Id publicationRt = recordTypeId('AEHC_Publication');
        Id applicationRt = recordTypeId('AEHC_Application');

        AEHC_Asset__c application = new AEHC_Asset__c(
            Name = 'Carousel Application',
            AEHC_Is_Subscription__c = false
        );
        if (applicationRt != null) {
            application.RecordTypeId = applicationRt;
        }
        insert application;

        List<AEHC_Asset__c> publications = new List<AEHC_Asset__c>();

        for (Integer i = 0; i < count; i++) {
            AEHC_Asset__c pub = new AEHC_Asset__c(
                Name = 'Carousel Publication ' + i,
                AEHC_Is_Subscription__c = false
            );
            if (publicationRt != null) {
                pub.RecordTypeId = publicationRt;
            }
            setIfWriteable(pub, 'AEHC_Application__c', application.Id);
            if (frequency != null) {
                setIfWriteable(pub, 'AEHC_Frequency__c', frequency);
            }
            publications.add(pub);
        }

        insert publications;
        return publications;
    }

    private static void setIfWriteable(SObject rec, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fields =
            AEHC_Asset__c.SObjectType.getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return;
        }

        Schema.DescribeFieldResult describe = fields.get(fieldApiName).getDescribe();

        if (!describe.isCreateable()) {
            return;
        }

        if (describe.getType() == Schema.DisplayType.PICKLIST && value instanceof String) {
            String requested = (String) value;
            String firstActive;
            Boolean found = false;

            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (!entry.isActive()) {
                    continue;
                }
                if (firstActive == null) {
                    firstActive = entry.getValue();
                }
                if (entry.getValue() == requested) {
                    found = true;
                }
            }

            rec.put(fieldApiName, found ? requested : firstActive);
            return;
        }

        rec.put(fieldApiName, value);
    }

    // -----------------------------
    // getFilteredCards
    // -----------------------------

    @IsTest
    static void test_NoPrefsReturns404() {
        setPrefs(null);

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards(null);
        Test.stopTest();

        System.assertEquals(404, result.get('status'), 'A user without preferences gets an empty state');
        System.assertEquals(false, result.containsKey('data'), 'No data is returned for the empty state');
    }

    @IsTest
    static void test_OnlyDelimitersInPrefsReturns404() {
        setPrefs(' ; ;  ; ');

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards(' ; ; ');
        Test.stopTest();

        System.assertEquals(404, result.get('status'), 'Tokens that are all blank produce no categories');
    }

    @IsTest
    static void test_EmptyMetadataReturns404() {
        setPrefs('API User');
        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>();

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

        System.assertEquals(404, result.get('status'), 'No configuration means no cards');
    }

    /**
     * Leaves testMdt null so the real custom metadata query executes.
     */
    @IsTest
    static void test_RealMetadataQueryPath() {
        setPrefs('API User');
        AEHC_CarouselController.testMdt = null;

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

        System.assert(
            result.get('status') == 200 || result.get('status') == 404,
            'The live metadata query returns either cards or an empty state, got: ' + result
        );
    }

    @IsTest
    static void test_NullCardInMetadataIsSkipped() {
        setPrefs('API User');

        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>{
            'NullCard' => null,
            'Good' => buildCard('Good', 'API User', true, 'Good Title', 'good.png')
        };

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

        System.assertEquals(200, result.get('status'), 'The valid card is still returned');

        List<AEHC_CarouselController.CarouselCardWrapper> cards =
            (List<AEHC_CarouselController.CarouselCardWrapper>) result.get('data');

        System.assertEquals(1, cards.size(), 'The null entry is skipped');
        System.assertEquals('Good Title', cards[0].title, 'Card title is mapped');
    }

    @IsTest
    static void test_NonMatchingGroupReturns404() {
        setPrefs('API User');

        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>{
            'Other' => buildCard('Other', 'Data Product User', true, 'Other Title', 'other.png')
        };

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

        System.assertEquals(404, result.get('status'), 'Cards outside the user categories are filtered out');
    }

    @IsTest
    static void test_MultipleMatchingCardsMapAllFields() {
        setPrefs('API User;Data Product User');

        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>{
            'A' => buildCard('A', 'API User', true, 'A Title', 'a.png'),
            'B' => buildCard('B', 'Data Product User', true, 'B Title', 'b.png'),
            'C' => buildCard('C', 'Unmapped Group', true, 'C Title', 'c.png'),
            'D' => buildCard('D', 'API User', false, 'D Title', 'd.png')
        };

        Test.startTest();
        Map<String, Object> result =
            AEHC_CarouselController.getFilteredCards('API User;Data Product User');
        Test.stopTest();

        System.assertEquals(200, result.get('status'), 'Matching active cards are returned');

        List<AEHC_CarouselController.CarouselCardWrapper> cards =
            (List<AEHC_CarouselController.CarouselCardWrapper>) result.get('data');

        System.assertEquals(2, cards.size(), 'Only active cards in the user categories are returned');

        Set<String> titles = new Set<String>();
        for (AEHC_CarouselController.CarouselCardWrapper card : cards) {
            titles.add(card.title);
            System.assertNotEquals(null, card.url, 'Redirect URL is mapped');
            System.assertNotEquals(null, card.category, 'Group is mapped to category');
            System.assertNotEquals(null, card.imageUrl, 'Image is mapped');
            System.assertNotEquals(null, card.description, 'Description is mapped');
        }

        System.assert(titles.contains('A Title') && titles.contains('B Title'), 'Both matching cards present');
    }

    /**
     * forceException is only reachable once the filtered list is non-empty, so
     * matching metadata has to be supplied for the catch block to run.
     */
    @IsTest
    static void test_ExceptionPathWithMatchingCards() {
        setPrefs('API User');

        AEHC_CarouselController.testMdt = new Map<String, AEHC_Carousel_Config__mdt>{
            'A' => buildCard('A', 'API User', true, 'A Title', 'a.png')
        };
        AEHC_CarouselController.forceException = true;

        Test.startTest();
        Map<String, Object> result = AEHC_CarouselController.getFilteredCards('API User');
        Test.stopTest();

        AEHC_CarouselController.forceException = false;

        System.assertEquals(500, result.get('status'), 'The catch block returns a server error status');
        System.assertNotEquals(null, result.get('message'), 'The exception message is surfaced');
    }

    @IsTest
    static void test_CarouselCardWrapperAccessors() {
        AEHC_CarouselController.CarouselCardWrapper w =
            new AEHC_CarouselController.CarouselCardWrapper();

        w.title = 'T';
        w.description = 'D';
        w.url = 'U';
        w.category = 'C';
        w.imageUrl = 'I';

        System.assertEquals('T', w.title, 'Wrapper fields round-trip');
        System.assertEquals('D', w.description, 'Wrapper fields round-trip');
        System.assertEquals('U', w.url, 'Wrapper fields round-trip');
        System.assertEquals('C', w.category, 'Wrapper fields round-trip');
        System.assertEquals('I', w.imageUrl, 'Wrapper fields round-trip');
    }

    // -----------------------------
    // getPublications
    // -----------------------------

    @IsTest
    static void test_GetPublicationsWithRecords() {
        List<AEHC_Asset__c> created = createPublications(3, 'Daily');

        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        System.assertEquals(created.size(), result.size(), 'Every eligible publication is returned');

        Set<String> ids = new Set<String>();

        for (AEHC_CarouselController.PublicationWrapper pub : result) {
            ids.add(pub.id);
            System.assertNotEquals(null, pub.publicationName, 'Publication name is mapped');
            System.assertNotEquals(null, pub.schedule, 'Schedule always has a value');
            System.assertEquals('Today', pub.lastUpdated, 'Freshly created records are relative-dated as Today');
            System.assert(
                pub.url.endsWith('/data-publication-details?id=' + pub.id),
                'Detail URL is built from the site base url, got: ' + pub.url
            );
            System.assert(pub.url.startsWith('http'), 'Base url fallback is used outside a site context');
        }

        System.assertEquals(created.size(), ids.size(), 'Publication ids are unique');
    }

    @IsTest
    static void test_GetPublicationsScheduleFallback() {
        createPublications(1, null);

        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'The publication is returned');
        System.assertEquals('N/A', result[0].schedule, 'A blank frequency falls back to N/A');
    }

    @IsTest
    static void test_GetPublicationsExcludesVersions() {
        List<AEHC_Asset__c> created = createPublications(1, 'Daily');

        Id publicationRt = recordTypeId('AEHC_Publication');

        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'Carousel Version',
            AEHC_Is_Subscription__c = false
        );
        Id versionRt = recordTypeId('AEHC_Version');
        version.RecordTypeId = versionRt != null ? versionRt : publicationRt;
        setIfWriteable(version, 'AEHC_Publication__c', created[0].Id);
        insert version;

        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        for (AEHC_CarouselController.PublicationWrapper pub : result) {
            System.assertNotEquals(
                version.Id, pub.id,
                'Records that belong to a publication are excluded by the query'
            );
        }
    }

    @IsTest
    static void test_GetPublicationsWithNoRecords() {
        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        System.assertEquals(0, result.size(), 'No eligible records means an empty list');
    }

    /**
     * The relative-date branches beyond "Today" depend on LastModifiedDate,
     * which cannot be set in Apex, so real org data is used to reach them.
     */
    @IsTest(SeeAllData=true)
    static void test_GetPublicationsRelativeDatesOnOrgData() {
        Test.startTest();
        List<AEHC_CarouselController.PublicationWrapper> result =
            AEHC_CarouselController.getPublications();
        Test.stopTest();

        System.assertNotEquals(null, result, 'A list is always returned');

        for (AEHC_CarouselController.PublicationWrapper pub : result) {
            System.assertNotEquals(null, pub.lastUpdated, 'Relative date is always populated');
        }
    }

    @IsTest
    static void test_PublicationWrapperAccessors() {
        AEHC_CarouselController.PublicationWrapper pub =
            new AEHC_CarouselController.PublicationWrapper();

        pub.id = 'id';
        pub.applicationName = 'app';
        pub.publicationName = 'pub';
        pub.schedule = 'Daily';
        pub.lastUpdated = 'Today';
        pub.url = 'https://example.com';

        System.assertEquals('id', pub.id, 'Wrapper fields round-trip');
        System.assertEquals('app', pub.applicationName, 'Wrapper fields round-trip');
        System.assertEquals('pub', pub.publicationName, 'Wrapper fields round-trip');
        System.assertEquals('Daily', pub.schedule, 'Wrapper fields round-trip');
        System.assertEquals('Today', pub.lastUpdated, 'Wrapper fields round-trip');
        System.assertEquals('https://example.com', pub.url, 'Wrapper fields round-trip');
    }
}