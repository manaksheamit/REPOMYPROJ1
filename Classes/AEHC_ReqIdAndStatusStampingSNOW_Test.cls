@isTest
public class AEHC_ReqIdAndStatusStampingSNOW_Test {

    // Mock for BOTH callouts
    class ServiceNowMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Token API
            if (req.getEndpoint() != null && req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_123","expires_in":3600}');
            } 
            // GET Request API
            else {
                res.setStatusCode(200);
                res.setBody(
                    '{"result":[{"stage":"In Progress","request_number":"REQ0012345"}]}'
                );
            }

            return res;
        }
    }

    @isTest
    static void testCreateRequest() {

        // Get RecordType
        RecordType rt = [SELECT Id FROM RecordType WHERE DeveloperName =: label.AEHC_SubReq_API_Asset_RecType LIMIT 1];

        // Create test data (IMPORTANT FIX)
        Subscription__c sub = new Subscription__c(
            AEHC_Purpose_of_Use__c = 'Testing',
            AEHC_IP_Address_of_the_Application__c = '10.10.10.10',
            AEHC_APM_Number__c = 'APM123',
            AEHC_SNow_Request__c = 'REQ0012345', // 
            RecordTypeId = rt.Id
        );
        insert sub;

        // Set mock
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock());

        Test.startTest();
        String result = AEHC_ReqIdAndStatusStampingSNOW.getRequestDetails(sub.Id);
        String token = AEHC_ReqIdAndStatusStampingSNOW.getAccessToken();
        Test.stopTest();
    }
    @isTest
static void testGetRequestDetails_Exception() {

    RecordType rt = [
        SELECT Id
        FROM RecordType
        WHERE DeveloperName = :Label.AEHC_SubReq_API_Asset_RecType
        LIMIT 1
    ];

    Subscription__c sub = new Subscription__c(
        AEHC_Purpose_of_Use__c = 'Testing',
        AEHC_IP_Address_of_the_Application__c = '10.10.10.10',
        AEHC_APM_Number__c = 'APM123',
        AEHC_SNow_Request__c = 'REQ0012345',
        RecordTypeId = rt.Id
    );
    insert sub;

    Test.setMock(
        HttpCalloutMock.class,
        new ServiceNowExceptionMock()
    );

    Test.startTest();
    String result =
        AEHC_ReqIdAndStatusStampingSNOW.getRequestDetails(sub.Id);
    Test.stopTest();

    // catch block returns null
    System.assertEquals(null, result);

    // Verify logger record created
    List<AEHC_Error_Event__c> logs = [
        SELECT Id,
               AEHC_Exception_Type__c,
               AEHC_Message__c
        FROM AEHC_Error_Event__c
    ];

    System.assert(logs.size() > 0,
        'AEHC_Logger.logException should have created a log record');
}
    
}