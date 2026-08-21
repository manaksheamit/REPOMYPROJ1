/**
 * @author Asif Ahmad
 * @date 22May2026
 * @description test class for AEHC_SNOW_ApplicationSearchService
*/
@isTest
public class AEHC_SNOW_ApplicationSearchService_Test {

    // ----------------------------------------
    // Mock for BOTH Auth + Search Callouts
    // ----------------------------------------
    class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            String endpoint = req.getEndpoint();
            System.debug('endpoint ' + endpoint);
            // Auth token API
            if(endpoint.contains('Auth')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token"}');
            }
            // Search API
            else {
                res.setStatusCode(200);
                res.setBody('{"result":[{"name":"App1"},{"name":"App2"}]}');
            }

            return res;
        }
    }

    @isTest
    static void testSearchApplication_Success_ByName() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();

        AEHC_APIHelper.Result result =
            AEHC_SNOW_ApplicationSearchService.searchApplication('TestApp');

        Test.stopTest();

        System.assertEquals(200, result.statusCode);
        System.assertNotEquals(null, result.data);

        List<Object> apps = (List<Object>) result.data;
        System.assert(apps.size() > 0);
    }
    
    @isTest
    static void testSearchApplication_Success_ByNumber() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();

        AEHC_APIHelper.Result result =
            AEHC_SNOW_ApplicationSearchService.searchApplication('APM7232');

        Test.stopTest();

        System.assertEquals(200, result.statusCode);
        System.assertNotEquals(null, result.data);

        List<Object> apps = (List<Object>) result.data;
        System.assert(apps.size() > 0);
    }
    
    @isTest
    static void test_invokeServiceNowAPI() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();

        AEHC_APIHelper.Result result =
            AEHC_SNOW_ApplicationSearchService.invokeServiceNowAPI('GET', 'name');

        Test.stopTest();

        System.assertEquals(200, result.statusCode);
        System.assertNotEquals(null, result.data);
    }
}