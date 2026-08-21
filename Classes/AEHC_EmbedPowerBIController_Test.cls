/**
 * @description       : Updated test class with complete metadata setup and NPE fixes
 * @author            : Amit Manakshe
 * @last modified on  : 07-01-2026
 * @last modified by  : Amit Manakshe
**/
@isTest
private class AEHC_EmbedPowerBIController_Test {
    
    // ---------------------------------------------------------
    // MOCKS
    // ---------------------------------------------------------
    private class MockPowerBICallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (endpoint.contains('/oauth2/') && method == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"access_token":"dummy_access_token"}');
                return res;
            }

            if (endpoint.contains('/reports/') && method == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"embedUrl":"https://app.powerbi.com/reportEmbed"}');
                return res;
            }

            if (endpoint.contains('GenerateToken') && method == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"token":"dummy_embed_token"}');
                return res;
            }

            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }

    private class MockErrorTokenCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invalid_client"}');
            return res;
        }
    }

    // ---------------------------------------------------------
    // UTILITIES
    // ---------------------------------------------------------
    private static void createUserRole(String roleName) {
        AEHC_AssetMember__c am = new AEHC_AssetMember__c(
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = roleName
        );
        insert am;
    }

    private static Config_Data__mdt buildFullMetadata() {
        return new Config_Data__mdt(
            DeveloperName = 'PowerBI',
            Attribute_1__c = 'tenantId',
            Attribute_2__c = 'workspace1',
            Attribute_3__c = 'report1',
            Attribute_4__c = 'MyNamedCred',
            Attribute_5__c = 'https://api.powerbi.com/v1.0/myorg/groups/',
            Attribute_6__c = 'client_id=abc,client_secret,UTF-8',
            Attribute_7__c = 'OK',              // REQUIRED to avoid NPE
            Attribute_8__c = 'Extra',           // Optional but safe
            Attribute_9__c = 'admin,developer',
            Attribute_10__c = true
        );
    }

    // ---------------------------------------------------------
    // TESTS
    // ---------------------------------------------------------

    @isTest
    static void testGetAllConfigsVisibility() {

        createUserRole('Developer');

        Test.startTest();
        List<Map<String,String>> configs = AEHC_EmbedPowerBIController.getAllConfigs();
        Test.stopTest();

        System.assertNotEquals(null, configs);
    }

    @isTest
    static void testGetEmbedInfoSuccess() {

        createUserRole('admin');

        Config_Data__mdt md = buildFullMetadata();
        AEHC_EmbedPowerBIController.mdRec = md;

        Test.setMock(HttpCalloutMock.class, new MockPowerBICallout());

        Test.startTest();
        Map<String,String> result = AEHC_EmbedPowerBIController.getEmbedInfo('PowerBI');
        Test.stopTest();

        System.assertEquals('https://app.powerbi.com/reportEmbed', result.get('embedUrl'));
        System.assertEquals('dummy_embed_token', result.get('embedToken'));
        System.assertEquals('report1', result.get('reportId'));
    }
    
    @isTest
    static void testGetEmbedInfoMissingMetadata() {

        Boolean thrown = false;

        try {
            AEHC_EmbedPowerBIController.getEmbedInfo('DoesNotExist');
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
    }

    @isTest
    static void testAzureTokenFailure() {

        Config_Data__mdt md = new Config_Data__mdt(
            DeveloperName = 'PowerBI',
            Attribute_1__c = 'tenantId',
            Attribute_4__c = 'MyNamedCred',
            Attribute_6__c = 'client_id=abc,client_secret,UTF-8',
            Attribute_7__c = 'Token Error'
        );

        AEHC_EmbedPowerBIController.mdRec = md;

        Test.setMock(HttpCalloutMock.class, new MockErrorTokenCallout());

        Boolean thrown = false;
        try {
            AEHC_EmbedPowerBIController.getAzureADAccessToken();
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
    }
}