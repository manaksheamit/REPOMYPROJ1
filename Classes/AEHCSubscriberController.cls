public without sharing class AEHCSubscriberController {

    @AuraEnabled
    public static SubscriberResponse getSubscribers( Id publicationId,String environment,String searchKey,Integer limitSize,Integer offsetVal ) {

        List<SubscriberWrapper> result = new List<SubscriberWrapper>();
        System.debug('Amit publicationId:-->'+publicationId);

        // Fetch Subscriptions
        Map<Id, Subscription__c> subscriptionMap = new Map<Id, Subscription__c>();
        Set<Id> apiSubscriptionIds = new Set<Id>();
        Set<Id> nonAPISubscriptionIds = new Set<Id>();

        for (Subscription__c sub : [ SELECT Id, AEHC_Consumming_Application__r.Name, AEHC_Environment_Name__c,CreatedDate,CreatedBy.Name,RecordType.DeveloperName
            FROM Subscription__c
            WHERE (AEHC_Publication_ID__c = :publicationId OR Community_Asset__c = :publicationId) ORDER BY CreatedDate DESC ]) 
            {
                subscriptionMap.put(sub.Id, sub);

                if (sub.RecordType.DeveloperName == 'API_Asset') {
                    apiSubscriptionIds.add(sub.Id);
                } else {
                    nonAPISubscriptionIds.add(sub.Id);
                }
        }
        System.debug('Amit subscriptionMap'+subscriptionMap.size()+subscriptionMap);
        System.debug('Amit apiSubscriptionIds'+apiSubscriptionIds.size()+apiSubscriptionIds);
        System.debug('Amit nonAPISubscriptionIds'+subscriptionMap.size()+nonAPISubscriptionIds);

        if (subscriptionMap.isEmpty()) {
            SubscriberResponse response = new SubscriberResponse();
            response.subscribers = new List<SubscriberWrapper>();
            response.totalCount = 0;
            
            return response;
        }

        /*
         * API_Asset Approvals
         */
        Map<Id, ProcessInstanceStep> apiApprovalMap = new Map<Id, ProcessInstanceStep>();

        if (!apiSubscriptionIds.isEmpty()) {

            for (ProcessInstanceStep step : [
                SELECT ProcessInstance.TargetObjectId,Actor.Name,CreatedDate,StepStatus
                FROM ProcessInstanceStep
                WHERE StepStatus = 'Approved'
                AND ProcessInstance.TargetObjectId IN :apiSubscriptionIds
                ORDER BY CreatedDate DESC
            ]) {

                Id targetId = step.ProcessInstance.TargetObjectId;

                if (!apiApprovalMap.containsKey(targetId)) {
                    apiApprovalMap.put(targetId, step);
                }
            }
            System.debug('Amit apiApprovalMap'+apiApprovalMap.size()+apiApprovalMap);


            for (Id subId : apiSubscriptionIds) {

                Subscription__c sub = subscriptionMap.get(subId);
                SubscriberWrapper wrap = new SubscriberWrapper();
                wrap.application = sub.AEHC_Consumming_Application__r != null? sub.AEHC_Consumming_Application__r.Name : null;
                wrap.createdDate = sub.CreatedDate;
                wrap.createdBy = sub.CreatedBy.Name;
                wrap.environment = sub.AEHC_Environment_Name__c;
                wrap.type = 'API Asset';

                if (apiApprovalMap.containsKey(subId)) {
                    ProcessInstanceStep step = apiApprovalMap.get(subId);
                    wrap.approver = step.Actor.Name;
                    wrap.approvedDate = step.CreatedDate;
                }

                if (String.isNotBlank(searchKey)) {
                    String key = searchKey.toLowerCase();
                    if ((wrap.application == null || !wrap.application.toLowerCase().contains(key)) && (wrap.environment == null || !wrap.environment.toLowerCase().contains(key))) {
                        continue;
                    }
                }

                if (wrap.approvedDate != null && wrap.approver != null) {
                    result.add(wrap);
                }
            }
            System.debug('Amit api result'+result.size()+result);
        }

        /*
         * Existing Version Logic
         */
        List<AEHC_Asset__c> versions = new List<AEHC_Asset__c>();

        if (!nonAPISubscriptionIds.isEmpty()) {

            versions = [
                SELECT Id,
                       CreatedDate,
                       CreatedBy.Name,
                       AEHC_Environment__c,
                       AEHC_Publication_Type__c,
                       AEHC_Subscription_Request__c
                FROM AEHC_Asset__c
                WHERE RecordType.DeveloperName = 'AEHC_Version'
                AND AEHC_Subscription_Request__c IN :nonAPISubscriptionIds
                ORDER BY CreatedDate DESC
                LIMIT :limitSize
                OFFSET :offsetVal
            ];
        }

        Map<Id, ProcessInstanceStep> approvalMap = new Map<Id, ProcessInstanceStep>();
        System.debug('Amit versions '+versions.size()+versions);

        if (!versions.isEmpty()) {

            for (ProcessInstanceStep step : [ SELECT ProcessInstance.TargetObjectId, Actor.Name,CreatedDate,StepStatus
                FROM ProcessInstanceStep
                WHERE StepStatus = 'Approved'
                AND ProcessInstance.TargetObjectId IN :versions
                ORDER BY CreatedDate DESC
            ]) {

                Id versionId = step.ProcessInstance.TargetObjectId;

                if (!approvalMap.containsKey(versionId)) {
                    approvalMap.put(versionId, step);
                }
            }

            for (AEHC_Asset__c ver : versions) {

                SubscriberWrapper wrap = new SubscriberWrapper();
                Subscription__c sub = subscriptionMap.get(ver.AEHC_Subscription_Request__c);

                wrap.application = (sub != null && sub.AEHC_Consumming_Application__r != null) ? sub.AEHC_Consumming_Application__r.Name : null;

                wrap.type = ver.AEHC_Publication_Type__c;
                wrap.createdDate = ver.CreatedDate;
                wrap.createdBy = ver.CreatedBy.Name;
                wrap.environment = ver.AEHC_Environment__c;

                if (approvalMap.containsKey(ver.Id)) {
                    ProcessInstanceStep step = approvalMap.get(ver.Id);
                    wrap.approver = step.Actor.Name;
                    wrap.approvedDate = step.CreatedDate;
                }

                if (String.isNotBlank(searchKey)) {

                    String key = searchKey.toLowerCase();

                    if ((wrap.application == null || !wrap.application.toLowerCase().contains(key)) && (wrap.environment == null || !wrap.environment.toLowerCase().contains(key)) ) {
                        continue;
                    }
                }

                if (wrap.approvedDate != null && wrap.approver != null) {
                    result.add(wrap);
                }
            }
        }

        Integer totalCount = apiSubscriptionIds.size() + [
                SELECT COUNT()
                FROM AEHC_Asset__c
                WHERE RecordType.DeveloperName = 'AEHC_Version'
                AND AEHC_Subscription_Request__c IN :nonAPISubscriptionIds
            ];

        SubscriberResponse response = new SubscriberResponse();
        response.subscribers = result;
        response.totalCount = totalCount;

        System.debug('Amit response'+response);

        return response;
    }

    public class SubscriberResponse {
        @AuraEnabled public List<SubscriberWrapper> subscribers;
        @AuraEnabled public Integer totalCount;
    }

    public class SubscriberWrapper {
        @AuraEnabled public String application;
        @AuraEnabled public String type;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String environment;
        @AuraEnabled public String approver;
        @AuraEnabled public Datetime approvedDate;
    }
}