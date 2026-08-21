@IsTest
public class AEHCAssetDetailControllerTest {

    /* ===================================================
       HTTP CALLOUT MOCKS
       =================================================== */

    private class UnityCatalogSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{ "columns": [' +
                '{"columnName":"etl_publn_id","dataType":"bigint","description":"Publication Identifier","nullable":true},' +
                '{"columnName":"record_id","dataType":"string","description":"Unique identifier","nullable":false}' +
                '] }'
            );
            return res;
        }
    }

    private class UnityCatalogErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service unavailable');
            return res;
        }
    }

    /* ===================================================
       RECORD TYPE HELPERS
       =================================================== */

    private static Id getRecordTypeId(String developerName) {
        return Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    /* ===================================================
       TEST DATA FACTORY
       =================================================== */

    private static Id createPublicationAsset() {

        Id applicationRtId  = getRecordTypeId('AEHC_Application');
        Id publicationRtId  = getRecordTypeId('AEHC_Publication');

        // ✅ Application Asset
        AEHC_Asset__c application = new AEHC_Asset__c(
            RecordTypeId = applicationRtId,
            Name = 'Test_Application',
            AEHC_Application_Id__c = 'APP-1001'
        );
        insert application;
		 string RcrdTyp =
            Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Publication')
                .getRecordTypeId();
        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordtypeID = RcrdTyp
        );
        insert pub;

        // ✅ Publication Asset (lookup → Application)
        AEHC_Asset__c publication = new AEHC_Asset__c(
            RecordTypeId = publicationRtId,
            Name = 'Test_Publication',
            AEHC_Application__c = application.Id,
            AEHC_Publication_Id__c = 'PUB-2001',
            AEHC_Publication_Type__c = 'Full',
            AEHC_Publication_Description__c = 'Test publication description',
            AEHC_Schedule__c = 'Daily',
            AEHC_Environment__c = 'Dev',AEHC_Publication__c = pub.Id,
            AEHC_Schema_Version__c = '1.0',
            AEHC_Is_Active__c = true
        );
        insert publication;

        return application.Id;
    }

    /* ===================================================
       TEST: getAsset
       =================================================== */

    @IsTest
    static void testGetAsset() {
        Id publicationId = createPublicationAsset();
		AEHC_Asset__c pub = [
            SELECT Id FROM AEHC_Asset__c WHERE Name = 'Test Publication' LIMIT 1
        ];
        Test.startTest();
        AEHCAssetDetailController.getAssets(pub.id,'Dev');
        Test.stopTest();
    }

    /* ===================================================
       TEST: getFieldsFromApi – SUCCESS PATH
       =================================================== */

    @IsTest
    static void testGetFieldsFromApiSuccess() {
        Id publicationId = createPublicationAsset();
        Test.setMock(HttpCalloutMock.class, new UnityCatalogSuccessMock());

        Test.startTest();
        AEHCAssetDetailController.getFieldsFromApi(
            publicationId,
            'Dev',
            10,
            0
        );
        Test.stopTest();
    }

    /* ===================================================
       TEST: getFieldsFromApi – ERROR PATH
       =================================================== */

    @IsTest
    static void testGetFieldsFromApiFailure() {
        Id publicationId = createPublicationAsset();
        Test.setMock(HttpCalloutMock.class, new UnityCatalogErrorMock());

        Test.startTest();
        try {
            AEHCAssetDetailController.getFieldsFromApi(
                publicationId,
                'Dev',
                10,
                0
            );
        } catch (Exception ignore) {
            // intentionally ignored
        }
        Test.stopTest();
    }

    /* ===================================================
       TEST: getPublicationContacts
       =================================================== */

    @IsTest
    static void testGetPublicationContacts() {
        Id publicationId = createPublicationAsset();

        Contact c = new Contact(
            LastName = 'Owner',
            Email = 'owner@test.com'
        );
        insert c;
		Profile p = [Select id from Profile where name =: AEHC_Constant.PROFILE_EXTERNAL_IDENTITY];

        User u = new User(
            Alias = 'tuser',
            Username = 'user' + System.currentTimeMillis() + '@test.com',
            LastName = 'user1234',
            Email = 'user@test.com',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = UserInfo.getProfileId()
            //ContactId = c.Id,LastName = 'test123'
        );
        insert u;

        AEHC_AssetMember__c member = new AEHC_AssetMember__c(
            AEHC_Asset__c = publicationId,
            AEHC_User__c  = u.Id,
            AEHC_Role__c  = 'Admin'
        );
        insert member;

        Test.startTest();
        AEHCAssetDetailController.getPublicationContacts(publicationId);
        Test.stopTest();
    }
}