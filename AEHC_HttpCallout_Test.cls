/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Test Class for AEHC_HttpCallout
*/
@isTest
public class AEHC_HttpCallout_Test {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    @isTest
    static void testSendAsGET() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        AEHC_HttpCallout callout = new AEHC_HttpCallout();
        Map<String, String> headers = new Map<String, String>();
        headers.put('Custom-Header', 'Value123');

        HttpResponse res = callout.sendAsGET('https://testendpoint.com', headers);

        System.assertEquals(200, res.getStatusCode());
        System.assert(res.getBody().contains('success'));
    }

    @isTest
    static void testSendAsPOST() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        AEHC_HttpCallout callout = new AEHC_HttpCallout();
        Map<String, String> headers = new Map<String, String>();
        headers.put('Authorization', 'Bearer token');

        String requestBody = '{"name":"Test"}';

        HttpResponse res = callout.sendAsPOST('https://testendpoint.com', requestBody, headers);

        System.assertEquals(200, res.getStatusCode());
        System.assert(res.getBody().contains('success'));
    }

    @isTest
    static void testSendWithException() {
        AEHC_HttpCallout callout = new AEHC_HttpCallout();
        
        HttpResponse res = callout.send('GET', 'invalidendpoint', null, null, null);

        System.assertEquals(500, res.getStatusCode(), 'Exception should set status code 500');
        System.assert(res.getBody().contains('message'));
        System.assertEquals('ApexException', res.getStatus());
    }

    @isTest
    static void testSendWithTimeoutAndHeaders() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        AEHC_HttpCallout callout = new AEHC_HttpCallout();
        Map<String, String> headers = new Map<String, String>{
            'Authorization' => 'Bearer 123'
        };

        HttpResponse res = callout.sendAsPOST('https://testendpoint.com', '{"test":"data"}', headers, 30000);
        System.assertEquals(200, res.getStatusCode());
        System.assert(res.getBody().contains('success'));
    }
}