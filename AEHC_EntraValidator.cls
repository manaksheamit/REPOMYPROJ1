public without sharing class AEHC_EntraValidator {
    public class Input {
        @InvocableVariable(required=true)
        public Id consumingApplicationId;

        @InvocableVariable(required=true)
        public String environment;
    }
    public class Output {
        @InvocableVariable
        public Boolean recordExists;
        @InvocableVariable
        public String applicationId;
        @InvocableVariable
        public String applicationName;
    }

    @InvocableMethod(label='Check Entra Request Exists')
    public static List<Output> checkSubscriptionExists(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output outRec = new Output();
            List<Subscription__c> subscriptions = [
                SELECT Id,
                       AEHC_Intra_Request__c,AEHC_Consuming_App_Registration_Name__c,AEHC_Consuming_App_Registration_ID__c
                FROM Subscription__c
                WHERE AEHC_Consumming_Application__c = :inp.consumingApplicationId
                AND AEHC_Environment_Name__c  = :inp.environment
                AND AEHC_Intra_Request__c != NULL
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];            
            if (!subscriptions.isEmpty()) {
                outRec.recordExists = true;
                outRec.applicationId = subscriptions[0].AEHC_Consuming_App_Registration_ID__c;
                outRec.applicationName = subscriptions[0].AEHC_Consuming_App_Registration_Name__c;
            } else {
                outRec.recordExists = false;
            }
            results.add(outRec);
        }
        return results;
    }
}