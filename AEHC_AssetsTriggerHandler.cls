public without sharing class AEHC_AssetsTriggerHandler {
    
        private static final String TARGET_RECORDTYPE = 'AEHC_Version'; 
        private static final String SUBMIT_TO_DDH = 'Submitted to DDH';
    
            private static Id getRecordTypeId() {
                return Schema.SObjectType.AEHC_Asset__c
                    .getRecordTypeInfosByDeveloperName()
                    .get(TARGET_RECORDTYPE)
                    .getRecordTypeId();
            }

	public static void afterInsert(List<AEHC_Asset__c> newList) {

        Set<Id> assetVerIds = new Set<Id>();
		Id rtId = getRecordTypeId();
        for (AEHC_Asset__c rec : newList) {
            if (rec.Approval_Status__c == SUBMIT_TO_DDH && rec.RecordTypeId == rtId) {  

					assetVerIds.add(rec.Id);
            }
        }

        if (!assetVerIds.isEmpty()) {
            System.enqueueJob(new AEHC_SubscriptionJobQueueable(assetVerIds));
        }
    }


    /**
     * After Update
     */
    public static void afterUpdate(
        Map<Id, AEHC_Asset__c> newMap,
        Map<Id, AEHC_Asset__c> oldMap
    ) {

        Set<Id> assetVerIds = new Set<Id>();
		Id rtId = getRecordTypeId();
        for (Id recId : newMap.keySet()) {

            AEHC_Asset__c newRec = newMap.get(recId);
            AEHC_Asset__c oldRec = oldMap.get(recId);
           
        if (
            newRec.Approval_Status__c == SUBMIT_TO_DDH && oldRec.Approval_Status__c != SUBMIT_TO_DDH && newRec.RecordTypeId == rtId) {
            assetVerIds.add(recId);
        }

        }

        if (!assetVerIds.isEmpty()) {
            System.enqueueJob(new AEHC_SubscriptionJobQueueable(assetVerIds));
        }
    }
}