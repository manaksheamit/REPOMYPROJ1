/**
 * @author Asif Ahmad
 * @date 22May2026
 * @description test class for AEHC_APIHelper
*/
@isTest
public class AEHC_APIHelper_Test {

    // -------------------------------
    // Mock class for HTTP Callout
    // -------------------------------
    class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;

        MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    // -------------------------------
    // Test: Successful Callout
    // -------------------------------
    @isTest
    static void testSuccessCallout() {

        Test.setMock(HttpCalloutMock.class, 
            new MockHttpResponseGenerator(200, '{"message":"success"}')
        );

        Test.startTest();

        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(
            'GET',
            'https://test.com',
            null,
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.stopTest();
        
        new AEHC_APIHelper.Result(200, null, null);

        System.assertEquals(200, response.getStatusCode());
        System.assertEquals('{"message":"success"}', response.getBody());
    }

    // -------------------------------
    // Test: Failed Callout (Error Logging Path)
    // -------------------------------
    @isTest
    static void testErrorCallout() {

        Test.setMock(HttpCalloutMock.class, 
            new MockHttpResponseGenerator(500, '{"error":"server issue"}')
        );

        Test.startTest();

        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(
            'POST',
            'https://test.com',
            '{"data":"test"}',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.stopTest();

        System.assertEquals(500, response.getStatusCode());
        System.assertEquals('{"error":"server issue"}', response.getBody());
        
        // Optional: If AEHC_Logger writes records, you can assert them here
        // Example:
        // List<Log__c> logs = [SELECT Id FROM Log__c];
        // System.assert(logs.size() > 0);
    }
}