public without sharing class AEHC_RITMValidator {

    public class Input {
        @InvocableVariable(required=true)
        public Id consumingApplicationId;

        @InvocableVariable(required=true)
        public String hostingLocation;
    }

    public class Output {
        @InvocableVariable
        public Boolean recordExists;
        
        @InvocableVariable
        public String serviceNowStatus;

        @InvocableVariable
        public String serviceNowRequest;

        @InvocableVariable
        public String intraRequest;

    }

    @InvocableMethod(label='Check Subscription Exists')
    public static List<Output> checkSubscriptionExists(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output outRec = new Output();
            List<Subscription__c> subscriptions = [
                SELECT Id,
                       AEHC_SNow_Status__c,
                       AEHC_SNow_Request__c,
                       AEHC_Intra_Request__c
                FROM Subscription__c
                WHERE AEHC_Consumming_Application__c = :inp.consumingApplicationId
                AND AEHC_Hosting_Location__c = :inp.hostingLocation
                AND AEHC_Hosting_Location__c != NULL
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];            
            if (!subscriptions.isEmpty()) {
                Subscription__c sub = subscriptions[0];
                outRec.recordExists = true;
                outRec.serviceNowStatus = sub.AEHC_SNow_Status__c;
                outRec.serviceNowRequest = sub.AEHC_SNow_Request__c;
                outRec.intraRequest = sub.AEHC_Intra_Request__c;
            } else {
                outRec.recordExists = false;
            }
            results.add(outRec);
        }
        return results;
    }
}