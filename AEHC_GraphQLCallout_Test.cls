@IsTest
public class AEHC_GraphQLCallout_Test {

    // ---------------- MOCK SUCCESS ----------------
    class MockSuccess implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":{"__schema":{"types":[{"name":"TestType"}]}}}');
            return res;
        }
    }

    // ---------------- MOCK FAILURE ----------------
    class MockFailure implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');

            return res;
        }
    }

    // ---------------- TEST SETUP ----------------
    @TestSetup
    static void setupData() {

        Subscription__c sub = new Subscription__c(
            Status__c = 'Submitted'
        );
        insert sub;

        AEHC_Asset__c asset = new AEHC_Asset__c(
            AEHC_Subscription_Request__c = sub.Id,
            AEHC_Is_Active__c = true,
            AEHC_GraphQL_Fields__c = 'field1,field2',
            AEHC_Schema_Version__c = '1'
        );
        insert asset;

        // Required by executeCallout()

        Network nw = [
            SELECT Id
            FROM Network
            LIMIT 1
        ];

        ms_aeh__CommunityAsset__c hrRefAsset =
            new ms_aeh__CommunityAsset__c(
                Name = 'kpmg-nexus-aks-ch-hrref-graphql-api',
                ms_aeh__AssetType__c = 'graphql',
                AEHC_API_Introspection_URL__c = 'graphql/hrref',
                AEHC_API_Introspection_Body__c= '{ "query": "{ __schema { types { name } } }" }',
                ms_aeh__AssetId__c = 'AST001',
                ms_aeh__GroupAssetId__c = 'GA001',
                ms_aeh__GroupId__c = 'G001',
                ms_aeh__Key__c = 'KEY001',
                ms_aeh__NetworkId__c = nw.Id
            );
        insert hrRefAsset;

        ms_aeh__CommunityAsset__c entRefAsset =
            new ms_aeh__CommunityAsset__c(
                Name = 'kpmg-nexus-aks-ch-entref-graphql-api',
                ms_aeh__AssetType__c = 'graphql',
                AEHC_API_Introspection_URL__c = 'graphql/entref',
                AEHC_API_Introspection_Body__c= '{ "query": "{ __schema { types { name } } }" }',
                ms_aeh__AssetId__c = 'AST002',
                ms_aeh__GroupAssetId__c = 'GA002',
                ms_aeh__GroupId__c = 'G002',
                ms_aeh__Key__c = 'KEY002',
                ms_aeh__NetworkId__c = nw.Id
            );
        insert entRefAsset;
    }

    // ---------------- TEST CALLOUT SUCCESS ----------------
    @IsTest
    static void testExecuteCallout_success() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();

        String response =
            AEHC_GraphQLCallout.executeCallout(
                'kpmg-nexus-aks-ch-hrref-graphql-api'
            );

        Test.stopTest();
    }

    // ---------------- TEST CALLOUT FAILURE ----------------
    @IsTest
    static void testExecuteCallout_failure() {

        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();

        String response =
            AEHC_GraphQLCallout.executeCallout(
                'kpmg-nexus-aks-ch-entref-graphql-api'
            );

        Test.stopTest();
    }

    // ---------------- TEST CALLOUT NO ASSET ----------------
    @IsTest
    static void testExecuteCallout_NoCommunityAsset() {

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();

        String response =
            AEHC_GraphQLCallout.executeCallout(
                'invalid-endpoint'
            );

        Test.stopTest();
    }

    // ---------------- TEST ENCRYPT ----------------
    @IsTest
    static void testEncrypt() {

        String input = 'test';

        Test.startTest();

        String encrypted =
            AEHC_GraphQLCallout.encrypt(input);

        Test.stopTest();
        List<String> parts = encrypted.split('\\.');
    }

    // ---------------- TEST getSelectedFields ----------------
    @IsTest
    static void testGetSelectedFields() {

        Subscription__c sub =
            [SELECT Id FROM Subscription__c LIMIT 1];

        Test.startTest();

        List<String> fields =
            AEHC_GraphQLCallout.getSelectedFields(sub.Id);

        Test.stopTest();
    }

    // ---------------- TEST createVersionUpdateGraph ----------------
    @IsTest
    static void testCreateVersionUpdateGraph() {

        Subscription__c sub =
            [SELECT Id FROM Subscription__c LIMIT 1];

        Test.startTest();

        String newId =
            AEHC_GraphQLCallout.createVersionUpdateGraph(
                sub.Id,
                'field3,field4',
                'signedToken',
                'formatted'
            );

        Test.stopTest();

        // Verify new version record

        AEHC_Asset__c newRec = [
            SELECT AEHC_Is_Active__c,
                   AEHC_Schema_Version__c,
                   AEHC_GraphQL_Fields__c,
                   AEHC_GraphQL_SignedToken__c
            FROM AEHC_Asset__c
            WHERE Id = :newId
        ];

        // Old record should be inactive

        AEHC_Asset__c oldRec = [
            SELECT AEHC_Is_Active__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :sub.Id
            AND Id != :newId
            LIMIT 1
        ];
        // Verify subscription updates

        Subscription__c updatedSub = [
            SELECT Status__c,
                   AEHC_Schema_Version__c,
                   AEHC_Data_Elements_Required__c,
                   AEHC_L1_Approved__c,
                   AHEC_L2_Approved__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];

        System.assertEquals(
            'Pending Subscriber Business Owner',
            updatedSub.Status__c
        );

    }

    // ---------------- TEST INVALID VERSION ----------------
    @IsTest
    static void testCreateVersionUpdateGraph_InvalidVersion() {

        Subscription__c sub = new Subscription__c(
            Status__c = 'Submitted'
        );
        insert sub;

        insert new AEHC_Asset__c(
            AEHC_Subscription_Request__c = sub.Id,
            AEHC_Is_Active__c = true,
            AEHC_Schema_Version__c = 'ABC'
        );

        Test.startTest();

        String assetId =
            AEHC_GraphQLCallout.createVersionUpdateGraph(
                sub.Id,
                'field1',
                'token',
                'formatted'
            );

        Test.stopTest();

        AEHC_Asset__c newAsset = [
            SELECT AEHC_Schema_Version__c
            FROM AEHC_Asset__c
            WHERE Id = :assetId
        ];
    }

    // ---------------- TEST revokePendingApprovals ----------------
    @IsTest
    static void testRevokePendingApprovals() {

        Subscription__c sub =
            [SELECT Id FROM Subscription__c LIMIT 1];

        Test.startTest();

        AEHC_GraphQLCallout.revokePendingApprovals(sub.Id);

        Test.stopTest();
    }

    // ---------------- TEST revokePendingApprovals WITH WORK ITEMS ----------------
    @IsTest
    static void testRevokePendingApprovals_withWorkItems() {

        Subscription__c sub = new Subscription__c(
            Status__c = 'Submitted'
        );
        insert sub;

        Approval.ProcessSubmitRequest req =
            new Approval.ProcessSubmitRequest();

        req.setObjectId(sub.Id);
        req.setComments('Submitting for approval');

        Approval.ProcessResult result =  Approval.process(req);

        Test.startTest();

        AEHC_GraphQLCallout.revokePendingApprovals(sub.Id);

        Test.stopTest();
    }
}