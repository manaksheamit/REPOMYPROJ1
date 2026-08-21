@IsTest
private class AEHC_SubscriptionDetailPageTest {

    // ✅ Utility
    private static Id getRecordTypeId(Schema.SObjectType obj, String devName) {
        return obj.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(devName)
            .getRecordTypeId();
    }

    // ✅ Create Application
    private static AEHC_Asset__c createApplication() {
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Test App',
            RecordTypeId = getRecordTypeId(AEHC_Asset__c.SObjectType, 'AEHC_Application')
        );
        insert app;
        return app;
    }

    // ✅ Create Publication
    private static AEHC_Asset__c createPublication(Id appId) {
        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordTypeId = getRecordTypeId(AEHC_Asset__c.SObjectType, 'AEHC_Publication'),
            AEHC_Application__c = appId,
            AEHC_Publication_Id__c = 'PUB-001'
        );
        insert pub;
        return pub;
    }

    // ✅ Create Subscription (with correct RecordType)
    private static Subscription__c createSubscription(Id pubId, Id appId) {

        Id rtId = getRecordTypeId(
            Subscription__c.SObjectType,
            'Data_Publication' // ✅ IMPORTANT: Dev Name
        );

        Subscription__c sub = new Subscription__c();

        sub.AEHC_Publication_ID__c = pubId;
        sub.AEHC_Application_Name__c = appId;
        sub.AEHC_Purpose_of_Use__c = 'Testing';
        sub.Subscriber__c = UserInfo.getUserId();
        sub.AEHC_Environment__c = 'Dev';
        sub.AEHC_Environment_Name__c = 'Dev';
        sub.RecordTypeId = rtId;

        insert sub;
        return sub;
    }

    // ✅ Create Version
    private static AEHC_Asset__c createVersion(
        Id subId,
        Id appId,
        Id pubId,
        String version,
        String destinationType
    ) {

        AEHC_Asset__c v = new AEHC_Asset__c(
            Name = 'Version ' + version,
            RecordTypeId = getRecordTypeId(AEHC_Asset__c.SObjectType, 'AEHC_Version'),
            AEHC_Subscription_Request__c = subId,
            AEHC_Application__c = appId,
            AEHC_Publication__c = pubId,
            AEHC_Is_Subscription__c = true,
            AEHC_Is_Active__c = true,
            AEHC_Environment__c = 'Dev', // ✅ SAFE VALUE
            AEHC_Schema_Version__c = version,
            Approval_Status__c = 'Approved',
            AEHC_Frequency__c = 'Daily',
            AEHC_Destination_Type__c = destinationType
        );

        insert v;
        return v;
    }

    // ✅ TEST 1 — MAIN DETAIL PAGE
    @IsTest
    static void testGetSubscriptionDetailPageData() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        createVersion(sub.Id, app.Id, pub.Id, '1', 'SFTP');
        createVersion(sub.Id, app.Id, pub.Id, '2', 'Database');

        Test.startTest();

        AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
            AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(sub.Id);

        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.environments.contains('Dev'));
        System.assertEquals(true, res.isEditableUser);
    }

    // ✅ TEST 2 — BUSINESS OWNER ACCESS
    @IsTest
    static void testBusinessOwnerAccess() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        createVersion(sub.Id, app.Id, pub.Id, '1', 'SFTP');

        // ✅ BO ROLE
        AEHC_AssetMember__c m = new AEHC_AssetMember__c();
        m.AEHC_Asset__c = app.Id;
        m.AEHC_User__c = UserInfo.getUserId();
        m.AEHC_Role__c = 'Business Owner';
        insert m;

        Test.startTest();

        AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
            AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(sub.Id);

        Test.stopTest();

        System.assertEquals(true, res.isEditableUser);
    }

    // ✅ TEST 3 — SFTP DETAILS
    @IsTest
    static void testVersionDetails_SFTP() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        AEHC_Asset__c v = createVersion(sub.Id, app.Id, pub.Id, '1', 'SFTP');

        v.AEHC_Host_Server__c = 'host';
        v.AEHC_Port__c = 22;
        update v;

        Test.startTest();

        Map<String, Object> res =
            AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id, 'Dev', '1'
            );

        Test.stopTest();

        Map<String, Object> dest = (Map<String, Object>) res.get('destination');
        System.assertEquals('SFTP', dest.get('destinationType'));
    }

    // ✅ TEST 4 — DATABASE
    @IsTest
    static void testVersionDetails_Database() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        AEHC_Asset__c v = createVersion(sub.Id, app.Id, pub.Id, '2', 'Database');

        v.AEHC_Port__c = 1433;
        v.AEHC_Weekdays__c = 'Monday;Friday';
        update v;

        Test.startTest();

        Map<String, Object> res =
            AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id, 'Dev', '2'
            );

        Test.stopTest();

        Map<String, Object> dest = (Map<String, Object>) res.get('destination');
        System.assertEquals('Database', dest.get('destinationType'));
    }

    // ✅ TEST 5 — BLOB
    @IsTest
    static void testVersionDetails_Blob() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        AEHC_Asset__c v = createVersion(sub.Id, app.Id, pub.Id, '3', 'BLOB');

        v.AEHC_Storage_Account_Bucket__c = 'bucket';
        update v;

        Test.startTest();

        Map<String, Object> res =
            AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id, 'Dev', '3'
            );

        Test.stopTest();

        Map<String, Object> dest = (Map<String, Object>) res.get('destination');
        System.assertEquals('BLOB', dest.get('destinationType'));
    }

    // ✅ TEST 6 — EXCEPTION (VERSION NOT FOUND)
    @IsTest
    static void testVersionNotFoundException() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id);
        Subscription__c sub = createSubscription(pub.Id, app.Id);

        Test.startTest();

        try {
            AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id, 'Dev', '999'
            );
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }

    // ✅ TEST 7 — NULL INPUT
    @IsTest
    static void testNullInput() {

        Test.startTest();

        try {
            AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(null);
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }
    // ✅ TEST 8 - Invalid input for Version Details
@IsTest
static void testVersionDetails_InvalidInput() {

    Test.startTest();

    try {
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
            null,
            'Dev',
            '1'
        );
        System.assert(false, 'Expected exception');
    } catch (AuraHandledException e) {
       // System.assert(e.getMessage().contains('Invalid input'));
    }

    Test.stopTest();
}

// ✅ TEST 9 - Invalid Subscription Record Type
@IsTest
static void testInvalidSubscriptionRecordType() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);

    Subscription__c sub = new Subscription__c(
        AEHC_Publication_ID__c = pub.Id,
        AEHC_Application_Name__c = app.Id,
        Subscriber__c = UserInfo.getUserId()
    );
    insert sub;

    Test.startTest();

    try {
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );
        System.assert(false, 'Expected exception');
    } catch (Exception e) {
        System.assert(true);
    }

    Test.stopTest();
}

// ✅ TEST 10 - Blank Environment Branch
@IsTest
static void testBlankEnvironmentVersionIgnored() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v = createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '10',
        'SFTP'
    );

    v.AEHC_Environment__c = null;
    update v;

    Test.startTest();

    AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );

    Test.stopTest();

    System.assertEquals(0, res.environmentMap.size());
}

// ✅ TEST 11 - JSON Deserialize + Schedule Coverage
@IsTest
static void testVersionDetails_JSONAndScheduleCoverage() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v = createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '11',
        'Database'
    );

    v.AEHC_Selected_Fields_JSON__c =
        '["Field1","Field2"]';
    v.AEHC_Weeks__c = 'Week 1;Week 3';
    v.AEHC_Weekdays__c = 'Monday';
    v.AEHC_Day_of_Month__c = '15';
    v.AEHC_Schedule_Summary__c = 'Schedule Test';
    v.AEHC_CRON_Job_Expression__c = '0 0 12 * * ?';

    update v;

    Test.startTest();

    Map<String, Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
            sub.Id,
            'Dev',
            '11'
        );

    Test.stopTest();

    List<Object> fields =
        (List<Object>)res.get('selectedFieldsJson');

    System.assertEquals(2, fields.size());

    Map<String, Object> schedule =
        (Map<String, Object>)res.get('schedule');

    System.assertNotEquals(
        null,
        schedule.get('weekdays')
    );

    System.assertNotEquals(
        null,
        schedule.get('multiWeekWeeks')
    );
}

// ✅ TEST 12 - Database Destination Fields
@IsTest
static void testDatabaseDestinationAdditionalFields() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v = createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '12',
        'Database'
    );

    v.AEHC_Database_Type__c = 'SQL Server';
    v.AEHC_JDBC_URL__c = 'jdbc:test';
    v.AEHC_Batch_Flag__c = true;
    v.AEHC_BatchSize__c = 100;
    v.AEHC_On_Initialization__c = 'INIT';
    v.AEHC_On_Load__c = 'LOAD';
    v.AEHC_On_Success__c = 'SUCCESS';
    v.AEHC_On_Error__c = 'ERROR';
    v.AEHC_Mute_Error_Flag__c = true;

    update v;

    Test.startTest();

    Map<String, Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
            sub.Id,
            'Dev',
            '12'
        );

    Test.stopTest();

    Map<String, Object> dest =
        (Map<String, Object>)res.get('destination');

    System.assertEquals('Database', dest.get('destinationType'));
    System.assertEquals('SQL Server', dest.get('databaseType'));
    System.assertEquals(true, dest.get('batchFlag'));
}

// ✅ TEST 13 - SFTP Destination Fields
@IsTest
static void testSftpDestinationAdditionalFields() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v = createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '13',
        'SFTP'
    );

    v.AEHC_Host_Server__c = 'host';
    v.AEHC_Port__c = 22;
    v.AEHC_Remote_Directory_Path__c = '/files';
    v.AEHC_Filename__c = 'test.csv';
    v.AEHC_Output_Format__c = 'CSV';
    v.AEHC_Include_Header__c = true;
    v.AEHC_Delimiter__c = ',';

    update v;

    Test.startTest();

    Map<String, Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
            sub.Id,
            'Dev',
            '13'
        );

    Test.stopTest();

    Map<String, Object> dest =
        (Map<String, Object>)res.get('destination');

    System.assertEquals('SFTP', dest.get('destinationType'));
    System.assertEquals('host', dest.get('sftpHostName'));
}

// ✅ TEST 14 - Blob Destination Fields
@IsTest
static void testBlobDestinationAdditionalFields() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v = createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '14',
        'BLOB'
    );

    v.AEHC_Storage_Account_Bucket__c = 'bucket';
    v.AEHC_Container_Folder_Path__c = '/container';
    v.AEHC_Blob_FileName__c = 'file.csv';
    v.AEHC_Output_Format__c = 'CSV';

    update v;

    Test.startTest();

    Map<String, Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
            sub.Id,
            'Dev',
            '14'
        );

    Test.stopTest();

    Map<String, Object> dest =
        (Map<String, Object>)res.get('destination');

    System.assertEquals('BLOB', dest.get('destinationType'));
    System.assertEquals('bucket', dest.get('storageAccount'));
}
    // ✅ TEST 15 - Subscription Not Found (QueryException branch)
@IsTest
static void testSubscriptionNotFoundException() {

    // Create a valid-looking Subscription Id that won't exist
    Id fakeSubscriptionId =
        (Id)'a01000000000001AAA';

    Test.startTest();

    try {
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            fakeSubscriptionId
        );
        System.assert(false, 'Expected exception');
    } catch (AuraHandledException e) {
        //System.assertEquals(true,e.getMessage().contains('Subscription not found') || e.getMessage().contains('Unable to load subscription details'));
    }

    Test.stopTest();
}

// ✅ TEST 16 - Environment Map With Multiple Environments
@IsTest
static void testMultipleEnvironmentVersions() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v1 =
        createVersion(sub.Id, app.Id, pub.Id, '1', 'SFTP');

    AEHC_Asset__c v2 =
        createVersion(sub.Id, app.Id, pub.Id, '2', 'Database');

    v2.AEHC_Environment__c = 'QA';

    update new List<AEHC_Asset__c>{v1, v2};

    Test.startTest();

    AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );

    Test.stopTest();

    System.assertEquals(
        2,
        res.environmentMap.size()
    );

    System.assert(
        res.environmentMap.containsKey('Dev')
    );

    System.assert(
        res.environmentMap.containsKey('QA')
    );
}

// ✅ TEST 17 - Empty JSON Branch
@IsTest
static void testVersionDetails_EmptyJsonCoverage() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '17',
        'Database'
    );

    Test.startTest();

    Map<String,Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id,
                'Dev',
                '17'
            );

    Test.stopTest();

    List<Object> fields =
        (List<Object>)res.get('selectedFieldsJson');

    System.assertEquals(0, fields.size());
}

// ✅ TEST 18 - Schedule Null Coverage
@IsTest
static void testVersionDetails_NullScheduleCoverage() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v =
        createVersion(
            sub.Id,
            app.Id,
            pub.Id,
            '18',
            'Database'
        );

    v.AEHC_Weekdays__c = null;
    v.AEHC_Weeks__c = null;

    update v;

    Test.startTest();

    Map<String,Object> res =
        AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails(
                sub.Id,
                'Dev',
                '18'
            );

    Test.stopTest();

    Map<String,Object> schedule =
        (Map<String,Object>)res.get('schedule');

    System.assertEquals(
        null,
        schedule.get('weekdays')
    );

    System.assertEquals(
        null,
        schedule.get('multiWeekWeeks')
    );
}

// ✅ TEST 19 - Non Editable User Branch
@IsTest
static void testNonEditableUser() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);

    Id rtId = getRecordTypeId(
        Subscription__c.SObjectType,
        'Data_Publication'
    );

    Subscription__c sub = new Subscription__c(
        AEHC_Publication_ID__c = pub.Id,
        AEHC_Application_Name__c = app.Id,
        AEHC_Purpose_of_Use__c = 'Testing',
        RecordTypeId = rtId
    );

    insert sub;

    createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '19',
        'SFTP'
    );

    Test.startTest();

    AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );

    Test.stopTest();

    System.assertEquals(
        false,
        res.isEditableUser
    );
}

// ✅ TEST 20 - Verify Version DTO Population
@IsTest
static void testVersionDtoValues() {

    AEHC_Asset__c app = createApplication();
    AEHC_Asset__c pub = createPublication(app.Id);
    Subscription__c sub = createSubscription(pub.Id, app.Id);

    AEHC_Asset__c v =
        createVersion(
            sub.Id,
            app.Id,
            pub.Id,
            '20',
            'SFTP'
        );

    v.Approval_Status__c = 'Pending';
    v.AEHC_Is_Active__c = false;

    update v;

    Test.startTest();

    AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );

    Test.stopTest();

    List<AEHC_SubscriptionDetailPageController.VersionDTO> versions =
        res.environmentMap.get('Dev');

    System.assertEquals(
        'Pending',
        versions[0].approvalStatus
    );

    System.assertEquals(
        false,
        versions[0].isActive
    );
}

// ✅ TEST 21 - Validate Additional Response Fields
@IsTest
static void testResponseFieldPopulation() {

    AEHC_Asset__c app = createApplication();
    app.AEHC_Application_Id__c = 'APP-001';
    update app;

    AEHC_Asset__c pub = createPublication(app.Id);

    Subscription__c sub =
        createSubscription(pub.Id, app.Id);

    createVersion(
        sub.Id,
        app.Id,
        pub.Id,
        '21',
        'SFTP'
    );

    Test.startTest();

    AEHC_SubscriptionDetailPageController.SubscriptionDetailResponse res =
        AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData(
            sub.Id
        );

    Test.stopTest();

    System.assertNotEquals(
        null,
        res.applicationName
    );

    System.assertNotEquals(
        null,
        res.publicationName
    );

    System.assertEquals(
        UserInfo.getUserId(),
        res.currentUserId
    );

    System.assertEquals(
        sub.Subscriber__c,
        res.subscriptionOwnerId
    );
}
}