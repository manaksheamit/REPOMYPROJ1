/**
 * @author Asif Ahmad
 * @date 16Apr2026
 * @description Test Class for AEHC_Mule_GetAPIService
*/
@IsTest
public class AEHC_Mule_GetAPIService_Test {

    /**
     * Mock class to simulate MuleSoft GraphQL API response
     */
    public class CalloutMocker implements HttpCalloutMock {
        
        String response;
        public CalloutMocker(String response) {
            this.response = response;
        }

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            // Mock GraphQL response with assets list
            String responseBody = this.response;

            res.setBody(responseBody);
            return res;
        }
    }

    /**
     * Test method for getAPIs()
     */
    @IsTest
    static void testGetAPIs_success() {

        // Register mock callout
        Test.setMock(HttpCalloutMock.class, new CalloutMocker('{"data":{"assets":[{"contactName":"LDAP-QUEUE","type":"rest-api"},{"contactName":"LDAP-QUEUE","type":"rest-api"},{"contactName":"LDAP-QUEUE","type":"http-api"},{"contactName":"HTTP-QUEUE","type":"http-api"}]}}'));

        Test.startTest();
        List<Object> assets = AEHC_Mule_GetAPIService.getAPIs();
        Test.stopTest();

        // Assertions
        System.assertNotEquals(
            null,
            assets,
            'Assets list should not be null'
        );

        System.assertEquals(
            4,
            assets.size(),
            'Assets list should contain 2 records'
        );
    }

    /**
     * Negative test: HTTP failure response
     */
    @IsTest static void testGetAPIs_httpFailure() {

        Test.setMock(HttpCalloutMock.class, new CalloutMocker('{"data":{"assets":[]}}'));

        Test.startTest();
        List<Object> assets = AEHC_Mule_GetAPIService.getAPIs();
        Test.stopTest();

        System.assertEquals(
            0,
            assets.size(),
            'Assets list should be empty when API fails'
        );
    }
}