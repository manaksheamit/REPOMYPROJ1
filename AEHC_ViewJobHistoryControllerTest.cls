@IsTest
public class AEHC_ViewJobHistoryControllerTest {

// ===============================
    // Mock: Job Runs SUCCESS
    // ===============================
    class JobRunsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String body = JSON.serialize(new Map<String, Object>{
                'runs' => new List<Object>{
                    new Map<String, Object>{
                        'runId' => 'RUN123',
                        'previousRunId' => 'RUN122',
                        'runStartTime' => '2024-01-01T10:00:00Z',
                        'runEndTime' => '2024-01-01T11:00:00Z',
                        'recordCount' => 100,
                        'status' => 'SUCCESS'
                    },
                    new Map<String, Object>{
                        'runId' => 'RUN124',
                        'previousRunId' => null,
                        'runStartTime' => null,
                        'runEndTime' => null,
                        'recordCount' => 50,
                        'status' => 'FAILED'
                    }
                }
            });

            res.setBody(body);
            return res;
        }
    }

    // ===============================
    // Mock: Audit SUCCESS
    // ===============================
    class AuditMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String body = JSON.serialize(new Map<String, Object>{
                'recordCount' => '50',
                'audit' => new List<Object>{
                    new Map<String, Object>{
                        'stage' => 'Validation',
                        'timestamp' => '2024-01-01T10:15:00Z',
                        'status' => 'SUCCESS',
                        'message' => 'OK'
                    }
                }
            });

            res.setBody(body);
            return res;
        }
    }

    // ===============================
    // Mock: ERROR
    // ===============================
    class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');
            return res;
        }
    }
    @testSetup
    static void setupData() {
        Account acc = new Account(Name='Test Acc');
        insert acc;
         User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    AEHC_Asset__c pubAsset = new AEHC_Asset__c(
            Name = 'Pub1',  // matches Publication Name
            AEHC_Is_Active__c = true,
            AEHC_Environment__c = 'Dev',
            AEHC_IntId__c = 'INT123'
        );
        insert pubAsset;
        
    insert new AEHC_AssetMember__c(
            AEHC_User__c = u.Id,
            AEHC_Role__c = 'Business Owner'
        );
    }

    // ===============================
    // TEST DATA SETUP
    // ===============================
    private static Subscription__c createTestSubscription() {
        Subscription__c sub = new Subscription__c(
            AEHC_Consuming_Application_Name__c = 'Test'
        );
        insert sub;
        return sub;
    }
    
    

    private static AEHC_Asset__c createAsset(String intId, Id subscriptionId) {
        AEHC_Asset__c asset = new AEHC_Asset__c(
            AEHC_IntId__c = intId,
            AEHC_Subscription_Request__c = subscriptionId,
            AEHC_Is_Active__c = true
        );
        insert asset;
        return asset;
    }

    // ===============================
    // TEST: getJobRuns SUCCESS
    // ===============================
    @IsTest
    static void testGetJobRuns_Success() {

        Subscription__c sub = createTestSubscription();
        createAsset('INT123', sub.Id);

        Test.setMock(HttpCalloutMock.class, new JobRunsMock());

        Test.startTest();
        AEHC_ViewJobHistoryController.JobRunsResponse response =
            AEHC_ViewJobHistoryController.getJobRuns(sub.Id, 'Dev');
        Test.stopTest();

    }

    // ===============================
    // TEST: No Asset Found
    // ===============================
    @IsTest
    static void testGetJobRuns_NoAsset() {

        Subscription__c sub = createTestSubscription();

        Test.startTest();
        try {
            AEHC_ViewJobHistoryController.getJobRuns(sub.Id, 'UAT');
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('List has no rows'));
        }
        Test.stopTest();
    }

    // ===============================
    // TEST: getAuditDetails SUCCESS
    // ===============================
    @IsTest
    static void testGetAuditDetails_Success() {

        Test.setMock(HttpCalloutMock.class, new AuditMock());

        Test.startTest();
        List<AEHC_ViewJobHistoryController.AuditWrapper> result =
            AEHC_ViewJobHistoryController.getAuditDetails('INT123', 'RUN123', 'DEV');
        	AEHC_ViewJobHistoryController.requestSnapshot('INT123', 'RUN123','DEV');
        	AEHC_ViewJobHistoryController.requestAdhoc('INT123','DEV');
        Test.stopTest();

    }
    
    @IsTest
    static void testGetAuditDetails_Failure() {

        Subscription__c sub = createTestSubscription();

        Test.startTest();
        try {
            AEHC_ViewJobHistoryController.getJobRuns(sub.Id, null);
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('List has no rows'));
        }
        Test.stopTest();

    }


}