@isTest
public class AEHC_CreateEntraRequest_Queueable_Test {

    /**
     * Success Mock
     * Handles both OAuth token callout and API callout
     */
    private class EntraSuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            // OAuth Call
            if(req.getHeader('Content-Type') == 'application/x-www-form-urlencoded'){

                res.setStatusCode(200);
                res.setBody(
                    '{"access_token":"test-access-token","token_type":"Bearer"}'
                );
            }
            // API Call
            else{

                res.setStatusCode(200);
                res.setBody(
                    '{"result":{"RequestNumber":"ENTRA12345","Message":"Success"}}'
                );
            }

            return res;
        }
    }

    /**
     * Failure Mock
     */
    private class EntraFailureMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated failure');
        }
    }

    @isTest
    static void testEntraQueueableSuccess() {

        Test.setMock(HttpCalloutMock.class, new EntraSuccessMock());

        Id rtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        Subscription__c sub = new Subscription__c(
            RecordTypeId = rtId,
            AEHC_Environment_Name__c = 'DEV',
            AEHC_Consuming_Application_Name__c = 'AppTest',
            AEHC_Purpose_of_Use__c = 'Testing'
        );

        insert sub;

        Test.startTest();

        System.enqueueJob(
            new AEHC_CreateEntraRequest_Queueable(
                new List<Id>{ sub.Id }
            )
        );

        Test.stopTest();

        Subscription__c updatedRec = [
            SELECT AEHC_Intra_Request__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];

        System.assertEquals(
            'ENTRA12345',
            updatedRec.AEHC_Intra_Request__c
        );
    }

    @isTest
    static void testEntraQueueableException() {

        Test.setMock(HttpCalloutMock.class, new EntraFailureMock());

        Id rtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        Subscription__c sub = new Subscription__c(
            RecordTypeId = rtId,
            AEHC_Environment_Name__c = 'DEV',
            AEHC_Consuming_Application_Name__c = 'AppTest',
            AEHC_Purpose_of_Use__c = 'Testing'
        );

        insert sub;

        Test.startTest();

        System.enqueueJob(
            new AEHC_CreateEntraRequest_Queueable(
                new List<Id>{ sub.Id }
            )
        );

        Test.stopTest();

        Subscription__c updatedRec = [
            SELECT AEHC_Intra_Request__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];

        System.assertEquals(
            null,
            updatedRec.AEHC_Intra_Request__c
        );
    }
}