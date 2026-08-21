public class AEHC_SubscriptionAPITriggerHandler {

    public static void handleAfterUpdate(List<Subscription__c> newList, Map<Id, Subscription__c> oldMap) {

        List<Id> entraIds = new List<Id>();
        List<Id> snowIds  = new List<Id>();
        List<Id> entraIdsUpdate  = new List<Id>();
        //AEHC_App_Registration_RITM_Status__c AEHC_Is_Entra_Request_Required__c
        // ✅ RecordType Map
        Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
            [SELECT Id, DeveloperName 
             FROM RecordType 
             WHERE SObjectType = 'Subscription__c']
        );

        for (Subscription__c newRec : newList) {

            Subscription__c oldRec = oldMap.get(newRec.Id);

            Boolean valid =
                newRec.Status__c == 'Approved' &&
                oldRec.Status__c != 'Approved' &&
                rtMap.get(newRec.RecordTypeId).DeveloperName == 'API_Asset';

            if (valid &&  newRec.AEHC_Is_RITM_Request_Required__c == true) {
                // ✅ ServiceNow condition
                if (String.isBlank(newRec.AEHC_SNow_Request__c)) {
                    snowIds.add(newRec.Id);
                }
            }
            if (valid && newRec.AEHC_Is_Entra_Request_Required__c == true) {
                // ✅ Entra condition
                if (String.isBlank(newRec.AEHC_Intra_Request__c)) {
                    entraIds.add(newRec.Id);
                }
            }
            if (valid && newRec.AEHC_Is_Entra_Request_Required__c == false) {
                // ✅ Entra condition
                if (String.isBlank(newRec.AEHC_Intra_Request__c)) {
                    entraIdsUpdate.add(newRec.Id);
                }
            }
        }

        // ✅ Call Entra Queueable
        if (!entraIds.isEmpty()) {
            System.enqueueJob(new AEHC_CreateEntraRequest_Queueable(entraIds));
        }

        // ✅ Call ServiceNow Queueable
        if (!snowIds.isEmpty()) {
            System.enqueueJob(new AEHC_ServiceNow_Queueable(snowIds));
        }
        // ✅ Call Update Entra Queueable
        if (!entraIdsUpdate.isEmpty()) {
            System.enqueueJob(new AEHC_UpdateEntraRequest_Queueable(entraIdsUpdate));
        }
    }
}