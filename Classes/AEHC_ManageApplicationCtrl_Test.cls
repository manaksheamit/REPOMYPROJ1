/**
 * @author Asif Ahmad
 * @date 20May2026
 * @description Test Class for AEHC_ManageApplicationCtr
*/
@isTest
public class AEHC_ManageApplicationCtrl_Test {

    // ---------------------------------------
    // Mock for ServiceNow Callout
    // ---------------------------------------
    class MockCallout implements HttpCalloutMock {
        public MockCallout() {}
        
        public String res;
        public MockCallout(String res) {
            this.res = res;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            String endpoint = req.getEndpoint();

            // Auth token API
            if(endpoint.contains('Auth')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token"}');
            }
            // Search API
            else {
                res.setStatusCode(200);
                res.setBody(this.res);
            }
            return res;
        }
    }

    // ---------------------------------------
    // Test: Found in Salesforce
    // ---------------------------------------
    @isTest
    static void testSearchApplication_FoundInSF() {

        // Create test record
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'TestApp',
            AEHC_Application_Id__c = 'APP001',
            RecordTypeId = Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName().get(AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION).getRecordTypeId(),
            AEHC_Is_Active__c = true
        );
        insert app;

        Test.startTest();

        Map<String, Object> response =
            AEHC_ManageApplicationCtrl.searchApplication('Test');

        Test.stopTest();

        System.assertEquals(200, response.get('status'));

        Map<String, Object> data = (Map<String, Object>)response.get('data');
        System.assertEquals(true, data.get('isFoundInSalesforce'));
    }

    // ---------------------------------------
    // Test: Not in SF -> Callout Success
    // ---------------------------------------
    @isTest
    static void test_searchApplication_success() {

        Test.setMock(HttpCalloutMock.class, new MockCallout('{"result":[{"name":"sdsd"},{"name":"sdsd2"}]}'));

        Test.startTest();

        Map<String, Object> response =
            AEHC_ManageApplicationCtrl.searchApplication('NoMatch');

        Test.stopTest();
    }
    
    @isTest
    static void test_getApplicationDetail() {

        // Create test record
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'TestApp',
            AEHC_Application_Id__c = 'APP001',
            RecordTypeId = Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName().get(AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION).getRecordTypeId(),
            AEHC_Is_Active__c = true
        );
        insert app;
        AEHC_Utility.addUserInAsset(app.Id, UserInfo.getUserId(), AEHC_Constant.ROLE_IT_OWNER, true);

        Test.startTest();

        Map<String, Object> response = AEHC_ManageApplicationCtrl.getApplicationDetail('{"id":"' + app.Id + '"}');

        Test.stopTest();
    }
    
    @isTest
    static void test_getApplicationDetail2() {

        Test.setMock(HttpCalloutMock.class, new MockCallout('{"result":{"name":"asasa","email":"asasas"}}'));
        
        AEHC_ManageApplicationCtrl.ApplicationDetail app = new AEHC_ManageApplicationCtrl.ApplicationDetail('APN012912','name1', 'b2', false);
        app.businessOwner = new AEHC_Utility.LookupField('https://www.g.co/t', 'u1', 'm1', false);
        app.ITOwner = new AEHC_Utility.LookupField('https://www.g.co/t', 'u1', 'm1', false);
        app.portfolio = 'https://www.g.co/t';

        Test.startTest();

        Map<String, Object> response = AEHC_ManageApplicationCtrl.getApplicationDetail(JSOn.serialize(app));

        Test.stopTest();
    }
    
    @isTest
    static void test_createApplication() {

        // Create test record
        AEHC_Asset__c appRec = new AEHC_Asset__c(
            Name = 'TestApp',
            AEHC_Application_Id__c = 'APP001',
            RecordTypeId = Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName().get(AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION).getRecordTypeId(),
            AEHC_Is_Active__c = true
        );
        insert appRec;
        
        AEHC_ManageApplicationCtrl.ApplicationDetail app = new AEHC_ManageApplicationCtrl.ApplicationDetail(appRec.Id,'name1', 'b2', false);
        app.businessOwner = new AEHC_Utility.LookupField(UserInfo.getUserId(), UserInfo.getUserId(), null, true);
        app.ITOwner = new AEHC_Utility.LookupField('https://www.g.co/t', UserInfo.getUserId(), null, true);
        app.portfolio = 'https://www.g.co/t';

        Test.startTest();

        Map<String, Object> response = AEHC_ManageApplicationCtrl.createApplication(JSOn.serialize(app));
        

        app.businessOwner = new AEHC_Utility.LookupField(appRec.Id, UserInfo.getUserId(), null, true);
        app.ITOwner = new AEHC_Utility.LookupField(appRec.Id, UserInfo.getUserId(), null, true);
        app.portfolio = 'https://www.g.co/t';

        response = AEHC_ManageApplicationCtrl.createApplication(JSOn.serialize(app));
        
        app = new AEHC_ManageApplicationCtrl.ApplicationDetail(appRec.Id,'name1', 'b2097320973029372093702', false);
        app.businessOwner = new AEHC_Utility.LookupField(appRec.Id, UserInfo.getUserId(), null, true);
        app.ITOwner = new AEHC_Utility.LookupField(appRec.Id, UserInfo.getUserId(), null, true);
        app.portfolio = 'https://www.g.co/t';

        response = AEHC_ManageApplicationCtrl.createApplication(JSOn.serialize(app));

        Test.stopTest();
    }
    
    
}