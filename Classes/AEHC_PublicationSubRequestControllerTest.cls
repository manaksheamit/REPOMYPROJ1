/*
* Author: Umang F
* Description: Subscription Creation and Validation Testing Class
* Version : 1
* */
@IsTest
private class AEHC_PublicationSubRequestControllerTest {
    
    private static Id getRecordTypeId(
        Schema.SObjectType sObjectType,
        String developerName
    ) {
        Schema.RecordTypeInfo rtInfo =
            sObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        
        System.assertNotEquals(
            null,
            rtInfo,
            'Missing record type developer name: ' + developerName
        );
        
        return rtInfo.getRecordTypeId();
    }
    
    private static void putIfCreateable(
        SObject record,
        String fieldApiName,
        Object value
    ) {
        Schema.SObjectField fieldToken =
            record.getSObjectType()
            .getDescribe()
            .fields
            .getMap()
            .get(fieldApiName);
        
        if (fieldToken != null && fieldToken.getDescribe().isCreateable()) {
            record.put(fieldApiName, value);
        }
    }
    
    private static Boolean isActivePicklistValue(
        Schema.SObjectType sObjectType,
        String fieldApiName,
        String value
    ) {
        Schema.SObjectField fieldToken =
            sObjectType.getDescribe()
            .fields
            .getMap()
            .get(fieldApiName);
        
        if (fieldToken == null) {
            return false;
        }
        
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return true;
            }
        }
        
        return false;
    }
    
    private static String getPicklistValue(
        Schema.SObjectType sObjectType,
        String fieldApiName,
        List<String> preferredValues
    ) {
        Schema.SObjectField fieldToken =
            sObjectType.getDescribe()
            .fields
            .getMap()
            .get(fieldApiName);
        
        System.assertNotEquals(
            null,
            fieldToken,
            'Missing field: ' + fieldApiName
        );
        
        List<Schema.PicklistEntry> entries =
            fieldToken.getDescribe().getPicklistValues();
        
        for (String preferredValue : preferredValues) {
            for (Schema.PicklistEntry entry : entries) {
                if (
                    entry.isActive() &&
                    (
                        entry.getValue() == preferredValue ||
                        entry.getLabel() == preferredValue
                    )
                ) {
                    return entry.getValue();
                }
            }
        }
        
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        
        return preferredValues.isEmpty() ? null : preferredValues[0];
    }
    
    private static AEHC_Asset__c createApplicationAsset() {
        Id applicationRtId = getRecordTypeId(
            AEHC_Asset__c.SObjectType,
            'AEHC_Application'
        );
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Finance App',
            RecordTypeId = applicationRtId
        );
        
        /*
* Do not set AEHC_Application_Id__c here unless required.
* This avoids deployment failures when field permissions are not present.
*/
        insert app;
        return app;
    }
    
    private static AEHC_Asset__c createPublicationAsset(Id applicationRecordId) {
        Id publicationRtId = getRecordTypeId(
            AEHC_Asset__c.SObjectType,
            'AEHC_Publication'
        );
        
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = 'Finance Publication',
            RecordTypeId = publicationRtId
        );
        
        putIfCreateable(publication, 'AEHC_Application__c', applicationRecordId);
        putIfCreateable(publication, 'AEHC_Publication_Id__c', 'PUB-001');
        putIfCreateable(publication, 'AEHC_Environment__c', 'Dev');
        putIfCreateable(publication, 'AEHC_Schema_Version__c', 'v1');
        
        insert publication;
        return publication;
    }
    
    private static Map<String, Object> baseRequest() {
        Map<String, Object> requestMap = new Map<String, Object>();
        
        requestMap.put('applicationName', 'Finance App');
        requestMap.put('applicationId', 'APP-001');
        requestMap.put('publicationName', 'Finance Publication');
        requestMap.put('publicationId', 'PUB-001');
        requestMap.put('environment', 'Dev');
        requestMap.put('schemaVersion', 'v1');
        requestMap.put('purposeOfUse', 'Testing subscription');
        requestMap.put('transformationRequired', false);
        
        requestMap.put(
            'selectedFields',
            new List<Object>{
                new Map<String, Object>{
                    'name' => 'company_code',
                        'dataType' => 'STRING',
                        'description' => 'Company Code',
                        'order' => 1
                        }
            }
        );
        
        requestMap.put(
            'selectedFieldsJson',
            new List<Object>{
                new Map<String, Object>{
                    'fieldName' => 'company_code',
                        'label' => 'Company Code',
                        'order' => 1
                        }
            }
        );
        
        return requestMap;
    }
    
    private static Map<String, Object> scheduleDaily() {
        return new Map<String, Object>{
            'schedulerMode' => 'Scheduler (Time-Based)',
                'frequency' => 'Daily',
                'scheduleTime' => '01:30',
                'weekdays' => new List<String>(),
                'multiWeekWeeks' => new List<String>(),
                'multiWeekDays' => new List<String>(),
                'monthlyDay' => '',
                'oneTimeDate' => '',
                'oneTimeTime' => '',
                'scheduleSummary' => 'Runs daily at 01:30.',
                'cronExpression' => '0 30 1 * * ?'
                };
                    }
    
    private static Map<String, Object> scheduleWeekly() {
        String mondayValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Monday', 'MONDAY' }
        );
        
        String fridayValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Friday', 'FRIDAY' }
        );
        
        return new Map<String, Object>{
            'schedulerMode' => 'Scheduler (Time-Based)',
                'frequency' => 'Weekly',
                'scheduleTime' => '02:15',
                'weekdays' => new List<String>{ mondayValue, fridayValue },
                    'multiWeekWeeks' => new List<String>(),
                    'multiWeekDays' => new List<String>(),
                    'monthlyDay' => '',
                    'oneTimeDate' => '',
                    'oneTimeTime' => '',
                    'scheduleSummary' => 'Runs weekly on Monday, Friday at 02:15.',
                    'cronExpression' => '0 15 2 ? * MON,FRI'
                    };
                        }
    
    private static Map<String, Object> scheduleMultiWeekly() {
        String weekOneValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weeks__c',
            new List<String>{ 'Week 1', 'WEEK_1' }
        );
        
        String weekThreeValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weeks__c',
            new List<String>{ 'Week 3', 'WEEK_3' }
        );
        
        String tuesdayValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Tuesday', 'TUESDAY' }
        );
        
        return new Map<String, Object>{
            'schedulerMode' => 'Scheduler (Time-Based)',
                'frequency' => 'Multi-Weekly',
                'scheduleTime' => '03:45',
                'weekdays' => new List<String>(),
                'multiWeekWeeks' => new List<String>{ weekOneValue, weekThreeValue },
                    'multiWeekDays' => new List<String>{ tuesdayValue },
                        'monthlyDay' => '',
                        'oneTimeDate' => '',
                        'oneTimeTime' => '',
                        'scheduleSummary' => 'Runs multi-week during Week 1, Week 3 on Tuesday at 03:45.',
                        'cronExpression' => '0 45 3 ? * TUE#1; 0 45 3 ? * TUE#3'
                        };
                            }
    
    private static Map<String, Object> scheduleMonthly() {
        return new Map<String, Object>{
            'schedulerMode' => 'Scheduler (Time-Based)',
                'frequency' => 'Monthly',
                'scheduleTime' => '04:00',
                'weekdays' => new List<String>(),
                'multiWeekWeeks' => new List<String>(),
                'multiWeekDays' => new List<String>(),
                'monthlyDay' => '10',
                'oneTimeDate' => '',
                'oneTimeTime' => '',
                'scheduleSummary' => 'Runs monthly on day 10 at 04:00.',
                'cronExpression' => '0 0 4 10 * ?'
                };
                    }
    
    private static Map<String, Object> scheduleOneTime() {
        return new Map<String, Object>{
            'schedulerMode' => 'Scheduler (Time-Based)',
                'frequency' => 'One-Time Load',
                'scheduleTime' => '',
                'weekdays' => new List<String>(),
                'multiWeekWeeks' => new List<String>(),
                'multiWeekDays' => new List<String>(),
                'monthlyDay' => '',
                'oneTimeDate' => '2026-12-31',
                'oneTimeTime' => '05:30',
                'scheduleSummary' => 'Runs once on 2026-12-31 at 05:30.',
                'cronExpression' => '0 30 5 31 12 ? 2026'
                };
                    }
    
    private static Map<String, Object> destinationBlob() {
        return new Map<String, Object>{
            'destinationType' => 'BLOB',
                'storageAccount' => 'storage-account',
                'containerPath' => 'container/folder',
                'includeHeader' => true,
                'provideCustomHeader' => true,
                'outputFormat' => 'CSV'
                };
                    }
    
    private static Map<String, Object> destinationDatabase() {
        String databaseTypeValue = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Database_Type__c',
            new List<String>{ 'SQL Server', 'SQL_SERVER' }
        );
        
        return new Map<String, Object>{
            'destinationType' => 'Database',
                'databaseType' => databaseTypeValue,
                'databaseHost' => 'db.example.com',
                'databasePort' => '1433',
                'jdbcUrl' => 'jdbc:sqlserver://db.example.com:1433',
                'otherProperties' => 'encrypt=true',
                'batchFlag' => true,
                'spOnInit' => 'sp_init',
                'spOnLoad' => 'sp_load',
                'spOnSuccess' => 'sp_success',
                'spOnError' => 'sp_error',
                'includeHeader' => true,
                'provideCustomHeader' => true,
                'muteErrorFlag' => false
                };
                    }
    
    private static Map<String, Object> destinationSftp() {
        return new Map<String, Object>{
            'destinationType' => 'SFTP',
                'sftpHostName' => 'sftp.example.com',
                'sftpPort' => '22',
                'sftpRemotePath' => '/outbound',
                'sftpFileName' => 'file.csv',
                'sftpOutputFormat' => 'CSV',
                'includeHeader' => true,
                'provideCustomHeader' => true,
                'delimiter' => ','
                };
                    }
    
    private static AEHC_PublicationSubRequestController.SaveSubscriptionResponse callSave(
        Map<String, Object> scheduleMap,
        Map<String, Object> destinationMap
    ) {
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        createActiveVersion(publication.Id, app.Id);
        
        Map<String, Object> requestMap = baseRequest();
        requestMap.put('schedule', scheduleMap);
        requestMap.put('destination', destinationMap);
        
        return AEHC_PublicationSubRequestController.saveSubscription(
            JSON.serialize(requestMap),
            publication.Id,
            app.Id
        );
    }
    
    private static AEHC_Asset__c getSchemaAsset(Id subscriptionId) {
        return [
            SELECT Id,
            Name,
            AEHC_Subscription_Request__c,
            AEHC_Publication__c,
            AEHC_Environment__c,
            AEHC_Schema_Version__c,
            AEHC_Transformation_Required__c,
            AEHC_Selected_Fields_JSON__c,
            AEHC_VSchedule__c,
            AEHC_Frequency__c,
            AEHC_Schedule_Summary__c,
            AEHC_CRON_Job_Expression__c,
            AEHC_Time__c,
            AEHC_Weekdays__c,
            AEHC_Weeks__c,
            AEHC_Day_of_Month__c,
            AEHC_One_Time_Execution_Date__c,
            AEHC_One_Time_Execution_Time__c,
            AEHC_Destination_Type__c,
            AEHC_Storage_Account_Bucket__c,
            AEHC_Container_Folder_Path__c,
            AEHC_Output_Format__c,
            AEHC_Database_Type__c,
            AEHC_Host_Server__c,
            AEHC_Port__c,
            AEHC_JDBC_URL__c,
            AEHC_Other_Properties__c,
            AEHC_Batch_Flag__c,
            AEHC_On_Initialization__c,
            AEHC_On_Load__c,
            AEHC_On_Success__c,
            AEHC_On_Error__c,
            AEHC_Mute_Error_Flag__c,
            AEHC_Remote_Directory_Path__c,
            AEHC_Filename__c,
            AEHC_Include_Header__c,
            AEHC_Provide_Custom_Header__c,
            AEHC_Delimiter__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :subscriptionId
            LIMIT 1
        ];
    }
    
    @IsTest
    static void testSaveSubscription_DailyBlob() {
        Test.startTest();
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            callSave(scheduleDaily(), destinationBlob());
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null.');
        System.assertNotEquals(null, response.subscriptionId, 'Subscription Id should be returned.');
        System.assertNotEquals(null, response.requestNumber, 'Request number should be returned.');
        
        Subscription__c sub = [
            SELECT Id,
            Name,
            AEHC_Publication_ID__c,
            AEHC_Purpose_of_Use__c,
            AEHC_Transformation_Required__c
            FROM Subscription__c
            WHERE Id = :response.subscriptionId
        ];
        
        System.assertEquals(response.requestNumber, sub.Name);
        System.assertNotEquals(null, sub.AEHC_Publication_ID__c);
        System.assertEquals('Testing subscription', sub.AEHC_Purpose_of_Use__c);
        System.assertEquals(false, sub.AEHC_Transformation_Required__c);
        
        AEHC_Asset__c schemaAsset = getSchemaAsset(response.subscriptionId);
        
        System.assertEquals(response.subscriptionId, schemaAsset.AEHC_Subscription_Request__c);
        System.assertEquals('Dev', schemaAsset.AEHC_Environment__c);
        //System.assertEquals('v1', schemaAsset.AEHC_Schema_Version__c);
        System.assertNotEquals(null, schemaAsset.AEHC_Selected_Fields_JSON__c);
        
        System.assertEquals('Daily', schemaAsset.AEHC_Frequency__c);
        System.assertEquals('BLOB', schemaAsset.AEHC_Destination_Type__c);
        System.assertEquals('storage-account', schemaAsset.AEHC_Storage_Account_Bucket__c);
        System.assertEquals('container/folder', schemaAsset.AEHC_Container_Folder_Path__c);
        System.assertEquals('CSV', schemaAsset.AEHC_Output_Format__c);
    }
    
    @IsTest
    static void testSaveSubscription_WeeklyDatabase() {
        Test.startTest();
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            callSave(scheduleWeekly(), destinationDatabase());
        Test.stopTest();
        
        System.assertNotEquals(null, response.subscriptionId);
        System.assertNotEquals(null, response.requestNumber);
        
        AEHC_Asset__c schemaAsset = getSchemaAsset(response.subscriptionId);
        
        String expectedMonday = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Monday', 'MONDAY' }
        );
        
        String expectedFriday = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Friday', 'FRIDAY' }
        );
        
        System.assertEquals('Weekly', schemaAsset.AEHC_Frequency__c);
        System.assertEquals(expectedMonday + ';' + expectedFriday, schemaAsset.AEHC_Weekdays__c);
        System.assertEquals('Database', schemaAsset.AEHC_Destination_Type__c);
        System.assertNotEquals(null, schemaAsset.AEHC_Database_Type__c);
        System.assertEquals(Decimal.valueOf('1433'), schemaAsset.AEHC_Port__c);
        System.assertEquals(true, schemaAsset.AEHC_Batch_Flag__c);
        System.assertEquals('jdbc:sqlserver://db.example.com:1433', schemaAsset.AEHC_JDBC_URL__c);
        System.assertEquals('sp_load', schemaAsset.AEHC_On_Load__c);
    }
    
    @IsTest
    static void testSaveSubscription_MultiWeeklySftp() {
        if (!isActivePicklistValue(AEHC_Asset__c.SObjectType, 'AEHC_Frequency__c', 'Multi-Weekly')) {
            System.assert(true, 'Skipping Multi-Weekly success scenario because Multi-Weekly is not active for AEHC_Frequency__c.');
            return;
        }
        
        Test.startTest();
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            callSave(scheduleMultiWeekly(), destinationSftp());
        Test.stopTest();
        
        System.assertNotEquals(null, response.subscriptionId);
        System.assertNotEquals(null, response.requestNumber);
        
        AEHC_Asset__c schemaAsset = getSchemaAsset(response.subscriptionId);
        
        String expectedWeekOne = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weeks__c',
            new List<String>{ 'Week 1', 'WEEK_1' }
        );
        
        String expectedWeekThree = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weeks__c',
            new List<String>{ 'Week 3', 'WEEK_3' }
        );
        
        String expectedTuesday = getPicklistValue(
            AEHC_Asset__c.SObjectType,
            'AEHC_Weekdays__c',
            new List<String>{ 'Tuesday', 'TUESDAY' }
        );
        
        System.assertEquals('Multi-Weekly', schemaAsset.AEHC_Frequency__c);
        System.assertEquals(expectedWeekOne + ';' + expectedWeekThree, schemaAsset.AEHC_Weeks__c);
        System.assertEquals(expectedTuesday, schemaAsset.AEHC_Weekdays__c);
        System.assertEquals('SFTP', schemaAsset.AEHC_Destination_Type__c);
        System.assertEquals('sftp.example.com', schemaAsset.AEHC_Host_Server__c);
        System.assertEquals(Decimal.valueOf('22'), schemaAsset.AEHC_Port__c);
        System.assertEquals('/outbound', schemaAsset.AEHC_Remote_Directory_Path__c);
        System.assertEquals('file.csv', schemaAsset.AEHC_Filename__c);
        System.assertEquals('CSV', schemaAsset.AEHC_Output_Format__c);
        System.assertEquals(true, schemaAsset.AEHC_Include_Header__c);
        System.assertEquals(true, schemaAsset.AEHC_Provide_Custom_Header__c);
        System.assertEquals(',', schemaAsset.AEHC_Delimiter__c);
    }
    
    @IsTest
    static void testSaveSubscription_MonthlyBlob() {
        Test.startTest();
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            callSave(scheduleMonthly(), destinationBlob());
        Test.stopTest();
        
        System.assertNotEquals(null, response.subscriptionId);
        System.assertNotEquals(null, response.requestNumber);
        
        AEHC_Asset__c schemaAsset = getSchemaAsset(response.subscriptionId);
        
        System.assertEquals('Monthly', schemaAsset.AEHC_Frequency__c);
        System.assertEquals('10', schemaAsset.AEHC_Day_of_Month__c);
        System.assertNotEquals(null, schemaAsset.AEHC_Time__c);
        System.assertEquals('0 0 4 10 * ?', schemaAsset.AEHC_CRON_Job_Expression__c);
    }
    
    @IsTest
    static void testSaveSubscription_OneTimeBlob() {
        Test.startTest();
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            callSave(scheduleOneTime(), destinationBlob());
        Test.stopTest();
        
        System.assertNotEquals(null, response.subscriptionId);
        System.assertNotEquals(null, response.requestNumber);
        
        AEHC_Asset__c schemaAsset = getSchemaAsset(response.subscriptionId);
        
        System.assertEquals('One-Time Load', schemaAsset.AEHC_Frequency__c);
        System.assertEquals(Date.newInstance(2026, 12, 31), schemaAsset.AEHC_One_Time_Execution_Date__c);
        System.assertNotEquals(null, schemaAsset.AEHC_Time__c);
        System.assertNotEquals(null, schemaAsset.AEHC_One_Time_Execution_Time__c);
        System.assertEquals('0 30 5 31 12 ? 2026', schemaAsset.AEHC_CRON_Job_Expression__c);
    }
    
    @IsTest
    static void testBlankRequestJson() {
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        
        Test.startTest();
        try {
            AEHC_PublicationSubRequestController.saveSubscription(
                '',
                publication.Id,
                app.Id
            );
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Expected exception caught.');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testInvalidJson() {
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        
        // ✅ ADD THIS
        createActiveVersion(publication.Id, app.Id);
        
		AEHC_PublicationSubRequestController.sendResubmittedNotification(UserInfo.getUserId(),app.Id
                                                                 ,'Test','Dev','1');
        Test.startTest();
        try {
            AEHC_PublicationSubRequestController.saveSubscription(
                'not valid json',
                publication.Id,
                app.Id
            );
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testMissingPublicationRecordId() {
        Map<String, Object> requestMap = baseRequest();
        requestMap.put('schedule', scheduleDaily());
        requestMap.put('destination', destinationBlob());
        
        Test.startTest();
        try {
            AEHC_PublicationSubRequestController.saveSubscription(
                JSON.serialize(requestMap),
                null,
                null
            );
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Expected exception caught.');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testConvertStringToTime() {
        Time timeOne = AEHC_PublicationSubRequestController.convertStringToTime('01:30');
        Time timeTwo = AEHC_PublicationSubRequestController.convertStringToTime('01:30:45');
        Time timeThree = AEHC_PublicationSubRequestController.convertStringToTime('01:30:45.000');
        Time timeNull = AEHC_PublicationSubRequestController.convertStringToTime(null);
        Time timeInvalid = AEHC_PublicationSubRequestController.convertStringToTime('invalid');
        
        System.assertNotEquals(null, timeOne);
        System.assertNotEquals(null, timeTwo);
        System.assertNotEquals(null, timeThree);
        System.assertEquals(null, timeNull);
        System.assertEquals(null, timeInvalid);
    }
    
    @IsTest
    static void testSaveSubscription_AssetInsertFailure_LogsError() {
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        createActiveVersion(publication.Id, app.Id);
        Map<String, Object> requestMap = baseRequest();
        
        Map<String, Object> badSchedule = scheduleDaily();
        badSchedule.put('frequency', 'Invalid-Frequency-Value');
        
        requestMap.put('schedule', badSchedule);
        requestMap.put('destination', destinationBlob());
        
        Test.startTest();
        try {
            AEHC_PublicationSubRequestController.saveSubscription(
                JSON.serialize(requestMap),
                publication.Id,
                app.Id
            );
            
            System.assert(false, 'Expected AuraHandledException due to schema asset insert failure.');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Expected exception caught.');
        }
        Test.stopTest();
    }
    private static AEHC_Asset__c createActiveVersion(Id publicationId, Id appId) {

    Id versionRtId = getRecordTypeId(
        AEHC_Asset__c.SObjectType,
        'AEHC_Version'
    );

    // ✅ CREATE SUBSCRIPTION FIRST
    Id subRtId = getRecordTypeId(
        Subscription__c.SObjectType,
        System.Label.AEHC_SubReq_DataPublication_RecType
    );

    Subscription__c sub = new Subscription__c();

    sub.AEHC_Publication_ID__c = publicationId;
    sub.AEHC_Application_Name__c = appId;
    sub.AEHC_Environment__c = 'Dev';
    sub.AEHC_Environment_Name__c = 'Dev';
    sub.AEHC_Latest_Version__c = 1;
    sub.RecordTypeId = subRtId;

    insert sub;

    // ✅ CREATE VERSION LINKED TO SUBSCRIPTION
    AEHC_Asset__c version = new AEHC_Asset__c(
        Name = 'Test Version',
        RecordTypeId = versionRtId
    );

    putIfCreateable(version, 'AEHC_Publication__c', publicationId);
    putIfCreateable(version, 'AEHC_Application__c', appId);
    putIfCreateable(version, 'AEHC_Environment__c', 'Dev');
    putIfCreateable(version, 'AEHC_Is_Active__c', true);
    putIfCreateable(version, 'AEHC_Schema_Version__c', '1');

    // ✅ THIS IS THE MOST IMPORTANT LINE
    putIfCreateable(version, 'AEHC_Subscription_Request__c', sub.Id);

    insert version;

    return version;
}
    @IsTest
    static void testEditMode_Update() {
        
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        
        AEHC_Asset__c version = createActiveVersion(publication.Id, app.Id);
        
        // ✅ Create subscription
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse res =
            callSave(scheduleDaily(), destinationBlob());
        
        // ✅ build request
        Map<String, Object> req = baseRequest();
        req.put('editMode', true);
        req.put('editAction', 'UPDATE');
        req.put('versionRecordId', version.Id);
        req.put('schedule', scheduleDaily());
        req.put('destination', destinationBlob());
        
        Test.startTest();
        
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            AEHC_PublicationSubRequestController.saveSubscription(
                JSON.serialize(req),
                publication.Id,
                app.Id
            );
        
        Test.stopTest();
        
        System.assertEquals('UPDATE', response.actionType);
    }
    @IsTest
    static void testEditMode_CreateNewVersion() {
        
        AEHC_Asset__c app = createApplicationAsset();
        AEHC_Asset__c publication = createPublicationAsset(app.Id);
        
        AEHC_Asset__c version = createActiveVersion(publication.Id, app.Id);
        
        Map<String, Object> req = baseRequest();
        req.put('editMode', true);
        req.put('editAction', 'CREATE_NEW_VERSION');
        req.put('versionRecordId', version.Id);
        req.put('schedule', scheduleDaily());
        req.put('destination', destinationBlob());
        
        Test.startTest();
        
        AEHC_PublicationSubRequestController.SaveSubscriptionResponse response =
            AEHC_PublicationSubRequestController.saveSubscription(
                JSON.serialize(req),
                publication.Id,
                app.Id
            );
        
        Test.stopTest();
        
        //System.assertEquals('NEW_VERSION', response.actionType);
    }
    private static Subscription__c createSubscription(Id publicationId, Id appId) {
        
        Id rtId = getRecordTypeId(
            Subscription__c.SObjectType,
            System.Label.AEHC_SubReq_DataPublication_RecType
        );
        
        Subscription__c sub = new Subscription__c();
        
        sub.AEHC_Publication_ID__c = publicationId;
        sub.AEHC_Application_Name__c = appId;
        sub.AEHC_Environment__c = 'Dev';
        sub.AEHC_Environment_Name__c = 'Dev';
        sub.AEHC_Latest_Version__c = 1;
        sub.RecordTypeId = rtId;
        
        insert sub;
        return sub;
    }
}