/**
 * @author Asif Ahmad
 * @date 21May2026
 * @description test class for AEHC_MuleFlex_AuthService
*/
@isTest
public class AEHC_MuleFlex_AuthService_Test {

    // --------------------------------------
    // Mock for Http Callout (200 success)
    // --------------------------------------
    class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"test_token_123"}');
            return res;
        }
    }

    // --------------------------------------
    // Mock for Http Callout (failure)
    // --------------------------------------
    class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invalid_request"}');
            return res;
        }
    }

    // --------------------------------------
    // Test: Success case
    // --------------------------------------
    @isTest
    static void testGetAuthToken_Success() {

        // Mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        // Inject metadata using Stub (if utility supports override, else rely on actual)
        Test.startTest();

        // If AEHC_Utility.getAPIConfig cannot be overridden,
        // ensure test metadata exists OR wrap method in future enhancement

        String token = AEHC_MuleFlex_AuthService.getAuthToken();

        Test.stopTest();

        System.assertEquals('test_token_123', token);
    }

    // --------------------------------------
    // Test: Failure case
    // --------------------------------------
    @isTest
    static void testGetAuthToken_Failure() {

        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();

        String token = AEHC_MuleFlex_AuthService.getAuthToken();

        Test.stopTest();

        System.assertEquals(null, token);
    }

    // --------------------------------------
    // Test: Null Metadata case
    // --------------------------------------
    @isTest
    static void testGetAuthToken_NoMetadata() {

        Test.startTest();

        // If AEHC_Utility returns null when no metadata is present,
        // this test validates early exit
        String token = AEHC_MuleFlex_AuthService.getAuthToken();

        Test.stopTest();

        System.assertEquals(null, token);
    }
}