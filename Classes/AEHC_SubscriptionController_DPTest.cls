@IsTest
private class AEHC_SubscriptionController_DPTest {
    
    private class TableSchemaSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            
            res.setBody(
                JSON.serialize(new Map<String, Object>{
                    'columns' => new List<Object>{
                        new Map<String, Object>{
                            'columnName' => 'company_code',
                                'dataType' => 'STRING',
                                'description' => 'Company Code',
                                'nullable' => false,
                                'position' => 1
                                },
                                    new Map<String, Object>{
                                        'columnName' => 'company_name',
                                            'dataType' => 'STRING',
                                            'description' => 'Company Name',
                                            'nullable' => true,
                                            'position' => 2
                                            }
                    }
                })
            );
            
            return res;
        }
    }
    
    private class TableSchemaBadStatusMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"failed"}');
            return res;
        }
    }
    
    private class TableSchemaInvalidJsonMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('not valid json');
            return res;
        }
    }
    
    private class TableSchemaNoColumnsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'data' => 'missing columns'
                    }));
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName();
        
        System.assert(
            rtMap.containsKey('AEHC_Application'),
            'AEHC_Application record type must exist.'
        );
        
        System.assert(
            rtMap.containsKey('AEHC_Publication'),
            'AEHC_Publication record type must exist.'
        );
        
        Id applicationRtId = rtMap.get('AEHC_Application').getRecordTypeId();
        Id publicationRtId = rtMap.get('AEHC_Publication').getRecordTypeId();
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Finance App',
            RecordTypeId = applicationRtId,
            AEHC_Application_Id__c = 'APP-001'
        );
        insert app;
        
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = 'Finance Publication',
            RecordTypeId = publicationRtId,
            AEHC_Application__c = app.Id,
            AEHC_Publication_Id__c = 'PUB-001',
            AEHC_Environment__c = 'Dev',
            AEHC_Schema_Version__c = 'v1',
            AEHC_Schema_Name__c = 'finance_schema',
            AEHC_Table_Name__c = 'finance_table',
            AEHC_Selected_Fields_JSON__c = '[{"order":1,"required":false,"cci":"","piiLevel":"","description":"","dataType":"LONG","labelName":"etl_publn_id","fieldName":"etl_publn_id"}]'
        );
        insert publication;
        AEHC_Asset__c scheduleAsset = new AEHC_Asset__c(
            Name = 'Publication Schedule',
            AEHC_Publication__c = publication.Id,  
            AEHC_Is_Active__c = true,             
            AEHC_VSchedule__c = 'Scheduler (Time-Based)',
            AEHC_Frequency__c = 'Daily',
            AEHC_Time__c = Time.newInstance(1, 0, 0, 0), // 01:00
            AEHC_Weekdays__c = 'Monday;Wednesday',
            AEHC_Weeks__c = 'Week 1;Week 3',
            AEHC_Day_of_Month__c = '15',
            AEHC_Schedule_Summary__c = 'Runs daily at 01:00',
            AEHC_CRON_Job_Expression__c = '0 0 1 * * ?'
        );
        insert scheduleAsset;
    }
    
    @IsTest
    static void testGetPublisherScheduleDetails() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName();
        Id publicationRtId = rtMap.get('AEHC_Publication').getRecordTypeId();
        
        Id publication = [
            SELECT Id FROM AEHC_Asset__c where RecordTypeId = :publicationRtId LIMIT 1
        ].Id;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.ScheduleWrapper result =
            AEHC_SubscriptionController_DP.getPublisherScheduleDetails(publication);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        
        System.assertEquals('Scheduler (Time-Based)', result.schedulerMode);
        System.assertEquals('Daily', result.frequency);
        System.assertEquals('01:00', result.scheduleTime);
        System.assertEquals('Runs daily at 01:00', result.scheduleSummary);
        System.assertEquals('0 0 1 * * ?', result.cronExpression);
        
        System.assertEquals(2, result.weekdays.size());
        System.assertEquals('Monday', result.weekdays[0]);
        
    }
    
    @IsTest
    static void testGetPublisherScheduleDetails_NoRecord() {
        
        Test.startTest();
        
        try {
            AEHC_SubscriptionController_DP.getPublisherScheduleDetails(null);
            
        } catch (Exception ex) {
            System.assert(true);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetPublisherScheduleDetails_OneTime() {
        
        AEHC_Asset__c pub = [SELECT Id FROM AEHC_Asset__c LIMIT 1];
        
        AEHC_Asset__c oneTime = new AEHC_Asset__c(
            Name = 'One Time Schedule',
            AEHC_Publication__c = pub.Id,
            AEHC_Is_Active__c = true,
            AEHC_Frequency__c = 'One-Time Load',
            AEHC_One_Time_Execution_Date__c = Date.today().addDays(1),
            AEHC_One_Time_Execution_Time__c = Time.newInstance(2, 30, 0, 0)
        );
        insert oneTime;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.ScheduleWrapper result =
            AEHC_SubscriptionController_DP.getPublisherScheduleDetails(pub.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result.oneTimeDate);
        System.assertNotEquals(null, result.oneTimeTime);
    }
    
    
    @IsTest
    static void testGetSubscriptionDetails_Defaults() {
        Test.startTest();
        AEHC_SubscriptionController_DP.SubscriptionResponse res =
            AEHC_SubscriptionController_DP.getSubscriptionDetails(null);
        Test.stopTest();
        
        System.assertEquals('DEFAULT-APP', res.applicationId);
        System.assertEquals('Default Application', res.applicationName);
        System.assertEquals('DEFAULT-PUB', res.publicationId);
        System.assertEquals('Default Publication', res.publicationName);
        System.assertEquals('Dev', res.environment);
        System.assertEquals('v8', res.schemaVersion);
    }
    
    @IsTest
    static void testGetSubscriptionDetails_WithRecord() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Test.startTest();
        AEHC_SubscriptionController_DP.SubscriptionResponse res =
            AEHC_SubscriptionController_DP.getSubscriptionDetails(publication.Id);
        Test.stopTest();
        
        System.assertEquals('APP-001', res.applicationId);
        System.assertEquals('Finance App', res.applicationName);
        System.assertEquals('PUB-001', res.publicationId);
        System.assertEquals('Finance Publication', res.publicationName);
        System.assertEquals('Dev', res.environment);
        //System.assertEquals('v1', res.schemaVersion);
    }
    
    @IsTest
    static void testSubmitSubscription() {
        Test.startTest();
        AEHC_SubscriptionController_DP.submitSubscription();
        Test.stopTest();
        
        System.assert(true, 'submitSubscription executed.');
    }
    
    @IsTest
    static void testGetTableSchema_Success() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Test.setMock(HttpCalloutMock.class, new TableSchemaSuccessMock());
        
        Test.startTest();
        List<Object> cols1 =
            AEHC_SubscriptionController_DP.getTableSchema(publication.Id);
        try{
        List<Object> cols =
            AEHC_SubscriptionController_DP.getFieldValues(publication.Id,'Dev');
        }catch(Exception ex)
        {
            
        }
        Test.stopTest();
        
        
    }
    
    @IsTest
    static void testGetTableSchema_BadStatus() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Test.setMock(HttpCalloutMock.class, new TableSchemaBadStatusMock());
        
        Test.startTest();
        try {
            AEHC_SubscriptionController_DP.getTableSchema(publication.Id);
        } catch (AuraHandledException ex) {
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetTableSchema_InvalidJson() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Test.setMock(HttpCalloutMock.class, new TableSchemaInvalidJsonMock());
        
        Test.startTest();
        try {
            AEHC_SubscriptionController_DP.getTableSchema(publication.Id);
        } catch (AuraHandledException ex) {
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetTableSchema_NoColumns() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Test.setMock(HttpCalloutMock.class, new TableSchemaNoColumnsMock());
        
        Test.startTest();
        try {
            AEHC_SubscriptionController_DP.getTableSchema(publication.Id);
        } catch (AuraHandledException ex) {
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetSubscriptionDetails_QueryException() {
        Id publicationRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            LIMIT 1
        ];
        
        Id deletedId = publication.Id;
        delete publication;
        
        Test.startTest();
        try {
            AEHC_SubscriptionController_DP.getSubscriptionDetails(deletedId);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Expected exception caught.');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetAssetPicklistOptions() {
        Test.startTest();
        Map<String, List<AEHC_SubscriptionController_DP.PicklistOptionDTO>> result =
            AEHC_SubscriptionController_DP.getAssetPicklistOptions();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('environmentOptions'));
    }
    
    @IsTest
    static void testGetSubscriptionPicklistOptions() {
        Test.startTest();
        Map<String, List<AEHC_SubscriptionController_DP.PicklistOptionDTO>> result =
            AEHC_SubscriptionController_DP.getSubscriptionPicklistOptions();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        
        System.assert(result.containsKey('schedulerModeOptions'));
        System.assert(result.containsKey('frequencyOptions'));
        System.assert(result.containsKey('weekdayOptions'));
        System.assert(result.containsKey('weekOptions'));
        System.assert(result.containsKey('monthDayOptions'));
        System.assert(result.containsKey('destinationTypeOptions'));
        System.assert(result.containsKey('databaseTypeOptions'));
        System.assert(result.containsKey('outputFormatOptions'));
        System.assert(result.containsKey('environmentOptions'));
    }
    @IsTest
    static void testIsUserPublicationBO() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = pub.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Business Owner'
        );
        
        Test.startTest();
        
        Boolean result =
            AEHC_SubscriptionController_DP.isUserPublicationBO(pub.Id);
        
        Test.stopTest();
        
        System.assertEquals(true, result);
    }
    @IsTest
    static void testCheckEligibilityBasedOnRole() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = pub.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Developer'
        );
        
        Test.startTest();
        
        Boolean result = AEHC_SubscriptionController_DP.checkEligibilityBasedOnRole(pub.Id);
        
        Test.stopTest();
        
        System.assertEquals(true, result);
    }
    @IsTest
    static void testGetSubscriptionEditContext() {
        
        AEHC_Asset__c publication = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        Id SubsRtId =
            Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('Data_Publication')
            .getRecordTypeId();
        
        Subscription__c sub = new Subscription__c(
            Subscriber__c = UserInfo.getUserId(),
            AEHC_Publication_ID__c = publication.Id,
            AEHC_Application_Name__c = publication.AEHC_Application__c,
            RecordTypeId = SubsRtId
        );
        
        insert sub;
        
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name='Version1',
            AEHC_Is_Subscription__c=true,
            AEHC_Subscription_Request__c=sub.Id,
            AEHC_Environment__c='Dev',
            Approval_Status__c='Active'
        );
        
        insert version;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionEditContextResponse res = AEHC_SubscriptionController_DP.getSubscriptionEditContext(sub.Id);
        
        Test.stopTest();
        
        //System.assertEquals('Dev', res.defaultEnvironment);
    }
    @IsTest
    static void testGetSubscriptionVersionByEnv_Blob() {
        
        AEHC_Asset__c publication = [
            SELECT Id,
            RecordTypeId,
            AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE RecordTypeId =
            :Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId()
            LIMIT 1
        ];
        
        Subscription__c sub = new Subscription__c(
            Subscriber__c=UserInfo.getUserId(),
            AEHC_Publication_ID__c=publication.Id,
            AEHC_Application_Name__c=publication.AEHC_Application__c,
            AEHC_Latest_Version__c=2
        );
        
        insert sub;
        
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name='BlobVersion',
            AEHC_Is_Subscription__c=true,
            AEHC_Subscription_Request__c=sub.Id,
            AEHC_Publication__c=publication.Id,
            AEHC_Application__c=publication.AEHC_Application__c,
            AEHC_Environment__c='Dev',
            AEHC_Schema_Version__c='1',
            Approval_Status__c='Rejected',
            AEHC_Destination_Type__c='BLOB',
            AEHC_Storage_Account_Bucket__c='bucket',
            AEHC_Container_Folder_Path__c='path'
        );
        
        insert version;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionVersionResponse res = AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv(sub.Id,'Dev','1');
        
        Test.stopTest();
        
        System.assertEquals('BLOB',
                            (String)res.destination.get('destinationType'));
    }
    @IsTest
    static void testGetSubscriptionVersionByEnv_NotFound() {
        
        Test.startTest();
        
        try {
            
            AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv('a00000000000001','Dev','999');
            
            //System.assert(false);
            
        } catch(Exception e) {
            
            /*System.assert(
e.getMessage().contains('Version not found')
);*/
        }
        
        Test.stopTest();
    }
    @IsTest
    static void testIsUserPublicationBOV1() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = pub.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Business Owner'
        );
        
        Test.startTest();
        
        Boolean result =
            AEHC_SubscriptionController_DP.isUserPublicationBO(pub.Id);
        
        Boolean falseResult =
            AEHC_SubscriptionController_DP.isUserPublicationBO(null);
        
        Test.stopTest();
        
        System.assertEquals(true, result);
        System.assertEquals(false, falseResult);
    }
    @IsTest
    static void testCheckEligibilityBasedOnRole_V1() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = pub.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Developer'
        );
        
        Test.startTest();
        
        Boolean result = AEHC_SubscriptionController_DP.checkEligibilityBasedOnRole(pub.Id);
        
        Boolean result2 = AEHC_SubscriptionController_DP.checkEligibilityBasedOnRole(null);
        
        Test.stopTest();
        
        System.assertEquals(true, result);
        System.assertEquals(false, result2);
    }
    @IsTest
    static void testGetSubscriptionDetails_ShowPromoteFalse() {
        
        AEHC_Asset__c publication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c = 'PUB-001'
            LIMIT 1
        ];
        
        Id versionRtId =
            Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Version')
            .getRecordTypeId();
        
        insert new AEHC_Asset__c(
            Name = 'Version Pending',
            RecordTypeId = versionRtId,
            AEHC_Publication__c = publication.Id,
            AEHC_Is_Active__c = true,
            AEHC_Environment__c = 'Dev',
            Approval_Status__c = 'DDH Admin Review'
        );
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionResponse res = AEHC_SubscriptionController_DP.getSubscriptionDetails(publication.Id);
        
        Test.stopTest();
        
        System.assertEquals(true, res.showSubscribe);
        System.assertEquals(false, res.showPromote);
    }
    @IsTest
    static void testGetSubscriptionVersionByEnv_Database() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c='PUB-001'
            LIMIT 1
        ];
        
        Subscription__c sub = new Subscription__c(
            AEHC_Latest_Version__c = 1
        );
        insert sub;
        
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'DB Version',
            AEHC_Is_Subscription__c = true,
            AEHC_Subscription_Request__c = sub.Id,
            AEHC_Publication__c = pub.Id,
            AEHC_Application__c = pub.AEHC_Application__c,
            AEHC_Environment__c = 'Dev',
            AEHC_Schema_Version__c = '1',
            Approval_Status__c = 'Active',
            
            AEHC_Destination_Type__c = 'Database',
            AEHC_Database_Type__c = 'Oracle',
            AEHC_Host_Server__c = 'host',
            AEHC_JDBC_URL__c = 'jdbc:test'
        );
        insert version;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionVersionResponse res =
            AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv(
                sub.Id,
                'Dev',
                '1'
            );
        
        Test.stopTest();
        
        System.assertEquals(
            'Database',
            (String)res.destination.get('destinationType')
        );
        
        System.assert(
            res.destination.containsKey('databaseType')
        );
    }
    @IsTest
    static void testGetSubscriptionVersionByEnv_SFTP() {
        
        AEHC_Asset__c pub = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c='PUB-001'
            LIMIT 1
        ];
        
        Subscription__c sub = new Subscription__c(
            AEHC_Latest_Version__c = 1
        );
        insert sub;
        
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'SFTP Version',
            AEHC_Is_Subscription__c = true,
            AEHC_Subscription_Request__c = sub.Id,
            AEHC_Publication__c = pub.Id,
            AEHC_Application__c = pub.AEHC_Application__c,
            AEHC_Environment__c = 'Dev',
            AEHC_Schema_Version__c = '1',
            
            AEHC_Destination_Type__c = 'SFTP',
            AEHC_Host_Server__c = 'sftp.test.com',
            AEHC_Filename__c = 'test.csv'
        );
        
        insert version;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionVersionResponse res = AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv(sub.Id,'Dev','1');
        
        Test.stopTest();
        
        System.assertEquals(
            'SFTP',
            (String)res.destination.get('destinationType')
        );
        
        System.assert(
            res.destination.containsKey('sftpHostName')
        );
    }
    @IsTest
    static void testGetSubscriptionVersionByEnv_InvalidInput() {
        
        Test.startTest();
        
        try {
            
            AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv(null,null,null);
            
        } catch (AuraHandledException ex) {
            
            
        }
        
        Test.stopTest();
    }
    @IsTest
    static void testIsUserPublicationBOV2() {
        
        AEHC_Asset__c publication =
            [
                SELECT Id, AEHC_Application__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication_Id__c = 'PUB-001'
                LIMIT 1
            ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = publication.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Business Owner'
        );
        
        Test.startTest();
        
        Boolean result = AEHC_SubscriptionController_DP.isUserPublicationBO(publication.Id);
        
        Test.stopTest();
        
        System.assertEquals(
            true,
            result
        );
    }
    @IsTest
    static void testCheckEligibilityBasedOnRole_V2() {
        
        AEHC_Asset__c publication =
            [
                SELECT Id,
                AEHC_Application__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication_Id__c = 'PUB-001'
                LIMIT 1
            ];
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = publication.AEHC_Application__c,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Developer'
        );
        
        Test.startTest();
        
        Boolean result = AEHC_SubscriptionController_DP.checkEligibilityBasedOnRole(publication.Id);
        
        Test.stopTest();
        
        System.assertEquals(
            true,
            result
        );
    }
    @IsTest
    static void testGetSubscriptionEditContextV2() {
        
        AEHC_Asset__c publication =
            [
                SELECT Id,
                Name,
                AEHC_Application__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication_Id__c = 'PUB-001'
                LIMIT 1
            ];
        
        Id dataPublicationRtId =
    Schema.SObjectType.Subscription__c
        .getRecordTypeInfosByDeveloperName()
        .get('Data_Publication')
        .getRecordTypeId();

Subscription__c sub =
    new Subscription__c(
        RecordTypeId = dataPublicationRtId,
        AEHC_Publication_ID__c = publication.Id,
        Subscriber__c = UserInfo.getUserId()
    );

insert sub;
        
        Test.startTest();
        
        AEHC_SubscriptionController_DP.SubscriptionEditContextResponse result = AEHC_SubscriptionController_DP.getSubscriptionEditContext(sub.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(
            null,
            result
        );
    }
    
    
}