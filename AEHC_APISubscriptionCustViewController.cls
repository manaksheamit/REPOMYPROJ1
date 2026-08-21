public with sharing class AEHC_APISubscriptionCustViewController {

    @AuraEnabled(cacheable=true)
    public static List<AEHC_Asset__c> getVersions(String subId) {

        return [
            SELECT Id,
                   AEHC_Schema_Version__c,
                   AEHC_Is_Active__c,
                   AEHC_GraphQL_Fields__c,
                   AEHC_GraphQL_SignedToken__c,
                   AEHC_Data_Elements_Required__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :subId
            ORDER BY CreatedDate DESC
        ];
    }
    

 @AuraEnabled(cacheable=true)
    public static List<ProcessInstanceStep> getApprovalHistory(Id recordId) {

        return [
            SELECT Id,
                   StepStatus,
                   CreatedDate,
                   OriginalActor.Name,
                   Actor.Name
            FROM ProcessInstanceStep
            WHERE ProcessInstance.TargetObjectId = :recordId
            ORDER BY CreatedDate DESC
        ];
    }

}