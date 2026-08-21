@IsTest
private class AEHC_UpdateEntraRequest_Queueable_Test {

    /**
     * Success Mock
     * Handles OAuth token callout + API callout
     */
    private class EntraRequestMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            // OAuth Token Call
            if (req.getHeader('Content-Type') == 'application/x-www-form-urlencoded') {

                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"access_token":"test-access-token","token_type":"Bearer"}'
                );

            } else {

                // Actual API Call
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"result":{' +
                    '"RequestNumber":"RITM123456",' +
                    '"Message":"Submitted Successfully"' +
                    '}}'
                );
            }

            return res;
        }
    }

    /**
     * Exception Mock
     */
    private class EntraFailureMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated failure');
        }
    }

    @IsTest
    static void testUpdateEntraRequestQueueable() {

        Id apiAssetRtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        Subscription__c sub = new Subscription__c(
            RecordTypeId = apiAssetRtId,
            AEHC_Environment_Name__c = 'QA',
            AEHC_Consuming_Application_Name__c = 'Test Application',
            AEHC_Purpose_of_Use__c = 'Testing'
        );

        insert sub;

        Test.setMock(HttpCalloutMock.class, new EntraRequestMock());

        Test.startTest();

        System.enqueueJob(
            new AEHC_UpdateEntraRequest_Queueable(
                new List<Id>{ sub.Id }
            )
        );

        Test.stopTest();

        Subscription__c updatedSub = [
            SELECT AEHC_Intra_Request__c,
                   AEHC_App_Registration_RITM_Status__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];


    }

    @IsTest
    static void testUpdateEntraRequestQueueable_Exception() {

        Id apiAssetRtId = Schema.SObjectType.Subscription__c
            .getRecordTypeInfosByDeveloperName()
            .get('API_Asset')
            .getRecordTypeId();

        Subscription__c sub = new Subscription__c(
            RecordTypeId = apiAssetRtId,
            AEHC_Environment_Name__c = 'QA',
            AEHC_Consuming_Application_Name__c = 'Test Application',
            AEHC_Purpose_of_Use__c = 'Testing'
        );

        insert sub;

        Test.setMock(HttpCalloutMock.class, new EntraFailureMock());

        Test.startTest();

        System.enqueueJob(
            new AEHC_UpdateEntraRequest_Queueable(
                new List<Id>{ sub.Id }
            )
        );

        Test.stopTest();

        Subscription__c updatedSub = [
            SELECT AEHC_Intra_Request__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];


    }
}