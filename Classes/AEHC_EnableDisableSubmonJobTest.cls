@isTest
public class AEHC_EnableDisableSubmonJobTest {
	
// ✅ MOCK SUCCESS RESPONSE
    class MockSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"SUCCESS"}');
            return res;
        }
    }

    // ✅ MOCK FAILURE RESPONSE
    class MockFailureResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"FAIL"}');
            return res;
        }
    }

    @testSetup
    static void setupData() {

        // ✅ Create required asset
        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = 'Test Asset',
            AEHC_Environment__c = 'Dev',
            AEHC_Is_Active__c = true
        );
        insert asset;

        /*
         ⚠️ IMPORTANT:
         Custom Metadata cannot be inserted directly in test context.
         So we assume your org already has:

         JobHistoryEndpointConfig__mdt with:
         - Environment__c = 'Dev'
         - JobType__c = 'LoadJob'
         - Endpoint_URL__c = 'https://test.com'

         If NOT -> this test will fail.
        */
    }

    // ✅ SUCCESS CASE
    @isTest
    static void testEnableDisableSubMonJob_Success() {

        AEHC_Asset__c asset = [
            SELECT Id, AEHC_IsJobEnable__c 
            FROM AEHC_Asset__c 
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());

        Test.startTest();
        Boolean result = AEHC_EnableDisableSubJob.enableDisableSubMonJob(asset.Id, true);
        Test.stopTest();

        // ✅ Assertion
        System.assertEquals(true, result);

        // ✅ Verify field updated
        AEHC_Asset__c updated = [
            SELECT AEHC_IsJobEnable__c 
            FROM AEHC_Asset__c 
            WHERE Id = :asset.Id
        ];

        System.assertEquals(true, updated.AEHC_IsJobEnable__c);
    }

    // ✅ FAILURE RESPONSE CASE
    @isTest
    static void testEnableDisableSubMonJob_FailureResponse() {

        AEHC_Asset__c asset = [
            SELECT Id FROM AEHC_Asset__c LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockFailureResponse());

        Test.startTest();
        Boolean result = AEHC_EnableDisableSubJob.enableDisableSubMonJob(asset.Id, false);
        Test.stopTest();

        // ✅ Should return false
        System.assertEquals(false, result);
    }
    
    @isTest
    static void testSubMonJobStatus_Success() {

        AEHC_Asset__c asset = [
            SELECT Id, AEHC_IsJobEnable__c 
            FROM AEHC_Asset__c 
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());

        Test.startTest();
        Map<String, Boolean> result = AEHC_EnableDisableSubJob.getJobSubmonStatus(asset.Id);
        Test.stopTest();

        
    }

}