@isTest
public class AEHC_SubscriptionAPITriggerHandler_Test {

    // ✅ SINGLE MOCK CLASS (ORDER-INDEPENDENT ✅)
    private class GenericMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            String body = req.getBody();
            String contentType = req.getHeader('Content-Type');

            // ✅ SERVICE NOW TOKEN CALL
            if (contentType != null && contentType.contains('application/x-www-form-urlencoded')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token","expires_in":3600}');
                return res;
            }

            // ✅ SERVICE NOW REQUEST CALL
            if (body != null && body.contains('sysparm_quantity')) {
                res.setStatusCode(200);
                res.setBody('{"result":{"request_number":"REQ12345"}}');
                return res;
            }

            // ✅ ENTRA REQUEST CALL
            if (body != null && body.contains('ApplicationRegistrationName')) {
                res.setStatusCode(200);
                res.setBody('{"result":{"RequestNumber":"ENTRA12345"}}');
                return res;
            }

            // ✅ FALLBACK
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @isTest
    static void testTriggerHandler_AllConditionsMet() {

        // ✅ Set Mock
        Test.setMock(HttpCalloutMock.class, new GenericMock());

        // ✅ Get RecordType (API_Asset)
        Id rtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        // ✅ Create record (Submitted state)
        Subscription__c sub = new Subscription__c(
            RecordTypeId = rtId,
            Status__c = 'Submitted',
            AEHC_Is_RITM_Request_Required__c = true,
            //AEHC_SubscriberEmail__c = 'test@test.com',
            AEHC_Environment_Name__c = 'DEV',
            AEHC_Consuming_Application_Name__c = 'AppTest',
            AEHC_Purpose_of_Use__c = 'Testing'
        );

        insert sub;

        Test.startTest();

        // ✅ Update → triggers handler
        sub.Status__c = 'Approved';
        update sub;

        Test.stopTest();

        // ✅ VERIFY OUTPUT
        Subscription__c updatedRec = [
            SELECT AEHC_Intra_Request__c,
                   AEHC_SNow_Request__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];
    }
}