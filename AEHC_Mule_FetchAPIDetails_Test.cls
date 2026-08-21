@IsTest
public class AEHC_Mule_FetchAPIDetails_Test {

    
    private class MuleAPISuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '  "labels": ["System API", "Customer", "v1"],' +
                '  "contactName": "test",' +
                '  "contactEmail": "test@test.com",' +
                '  "assetType": "rest"' +
                '}'
            );
            return res;
        }
    }

    
    private class MuleAPIEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '  "labels": [],' +
                '  "contactName": "test",' +
                '  "contactEmail": "test@test.com",' +
                '  "assetType": "rest"' +
                '}'
            );
            return res;
        }
    }

    
    @IsTest
    static void testGetAPIsAdditionalDetails_Success() {

        Test.setMock(HttpCalloutMock.class, new MuleAPISuccessMock());

        List<String> apiName = new List<String>{ 'sample-api' };

        Test.startTest();
        List<List<String>> result =
            AEHC_Mule_FetchAPIDetails.getAPIsAdditionalDetails(apiName);
        system.debug('results success:'+result);
        Test.stopTest();

        System.assertEquals(1, result.size(),
            'Outer list should contain one element');


        System.assertEquals('System API', result[0][0]);
        System.assertEquals('Customer', result[0][1]);
        System.assertEquals('v1', result[0][2]);
    }

    
    @IsTest
    static void testGetAPIsAdditionalDetails_EmptyLabels() {

        Test.setMock(HttpCalloutMock.class, new MuleAPIEmptyMock());

        List<String> apiName = new List<String>{ 'empty-api' };

        Test.startTest();
        List<List<String>> result =
            AEHC_Mule_FetchAPIDetails.getAPIsAdditionalDetails(apiName);
        system.debug('results empty:'+result);
        Test.stopTest();

        System.assertEquals(1, result.size(),
            'Outer list should still exist');

        System.assertEquals(3, result[0].size(),
            'Inner label list should be empty');
    }
}