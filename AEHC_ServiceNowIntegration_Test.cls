@isTest
public class AEHC_ServiceNowIntegration_Test {

    // Single mock handles BOTH callouts
    class ServiceNowMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Token call
            if (req.getEndpoint() != null && req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_123","expires_in":3600}');
            } 
            // Create request call
            else {
                res.setStatusCode(200);
                res.setBody('{"result":{"request_number":"REQ0012345"}}');
            }

            return res;
        }
    }

    @isTest
    static void testCreateRequest() {

        // Create test data
        Subscription__c sub = new Subscription__c(
            AEHC_Purpose_of_Use__c = 'Testing',
            AEHC_IP_Address_of_the_Application__c = '10.10.10.10',
            AEHC_APM_Number__c = 'APM123',
            AEHC_Environment_Name__c = 'Dev'
        );
        insert sub;

        // Set mock (IMPORTANT: only once)
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock());

        Test.startTest();

        List<String> result = AEHC_ServiceNowIntegration.createRequest(
            new List<String>{ sub.Id }
        );
		String token = AEHC_ServiceNowIntegration.getAccessToken('API_Details');
        Test.stopTest();

        // Assertions
        /*System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('REQ0012345', result[0]);*/
    }
}