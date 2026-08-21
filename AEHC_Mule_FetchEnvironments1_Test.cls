@IsTest
public class AEHC_Mule_FetchEnvironments1_Test {

    private class MuleMultiEndpointMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();

            if (endpoint.contains('/environments')) {
                res.setBody(
                    '{' +
                    ' "data": [' +
                    '   {"id":"env1","name":"Sandbox"},' +
                    '   {"id":"env2","name":"Production"}' +
                    ' ]' +
                    '}'
                );
            }
            else if (endpoint.contains('/asset') && !endpoint.contains('/instances')) {
                res.setBody(
                    '{' +
                    ' "assetId":"asset123",' +
                    ' "versionGroup":"vg1"' +
                    '}'
                );
            }
            else if (endpoint.contains('/instances')) {
                res.setBody(
                    '[' +
                    ' {"environmentId":"env1"},' +
                    ' {"environmentId":"env2"}' +
                    ']'
                );
            }
            return res;
        }
    }

    @IsTest
    static void testGetAllEnvironmentNames() {

        Test.setMock(HttpCalloutMock.class, new MuleMultiEndpointMock());

        Test.startTest();
        Map<String, String> result =
            AEHC_Mule_FetchEnvironments1.getAllEnvironmentNames();
        Test.stopTest();

    }

    @IsTest
    static void testGetAPIRelEnvironments() {

        Test.setMock(HttpCalloutMock.class, new MuleMultiEndpointMock());

        List<String> apiName = new List<String>{ 'sample-api' };

        Test.startTest();
        List<List<AEHC_PicklistValue>> result =
            AEHC_Mule_FetchEnvironments1.getAPIRelEnvironments(apiName);
        Test.stopTest();

        System.assertEquals(1, result.size(),
            'Wrapper list should contain one element');

        List<AEHC_PicklistValue> options = result[0];

    }

    @IsTest
    static void testGetAPIsEnv() {

        Test.setMock(HttpCalloutMock.class, new MuleMultiEndpointMock());

        Test.startTest();
        String response =
            AEHC_Mule_FetchEnvironments1.getAPIsEnv('asset123', 'vg1');
        Test.stopTest();

    }
}