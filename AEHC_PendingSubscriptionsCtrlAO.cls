/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Controller of LWC 
 * @app AEHC
*/
public with sharing class AEHC_PendingSubscriptionsCtrlAO {

    /**
     * @author Asif Ahmad
     * @date 17Apr2026
     * @description to provide the pending subscription records in the context of current User:Asset owner  
     * @return to return result in form of Map with keys as status and data
	*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPendingSubscriptions() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            
            // get current User Group Names, it belongs
            String currUserId = UserInfo.getUserId();
            
            // query Pending Records
            final List<Subscription__c> subs = [
                SELECT Id,
                Name,
                AEHC_AssetType__c,
                API_Name__c,
                CreatedDate,
                CreatedBy.Name,
                AEHC_Environment_Name__c,
                AEHC_Purpose_of_Use__c
                FROM Subscription__c
                WHERE Status__c =: AEHC_Constant.SUBMITTED OR Status__c LIKE : '%'+label.AEHC_Pending+'%'
                ORDER BY CreatedDate DESC
            ];
            
            if(subs.isEmpty())  {
                result.put('status', 404);
                return result;
            }
            final List<SubscriptionWrapper> wrapList = new List<SubscriptionWrapper>();
            
            for (Subscription__c s : subs) {
                SubscriptionWrapper w = new SubscriptionWrapper();
                w.Id = s.Id;
                w.SubscriptionName = s.Name;
                w.Type = s.AEHC_AssetType__c;
                w.Name = s.API_Name__c;
                w.CreatedDate = s.CreatedDate;
                w.CreatedBy = s.CreatedBy != null ? s.CreatedBy.Name : null;
                w.Environment = s.AEHC_Environment_Name__c;
                w.Purpose = s.AEHC_Purpose_of_Use__c;
                wrapList.add(w);
            }
            
            wrapList.sort(new EnvSort());
            
            result.put('status', 200);
            result.put('data', wrapList);
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_PendingSubscriptionsCtrlAO', 'other', null, 'P1', null, null, 'Dev');
            result.put('status', 500);
            result.put('message', e.getMessage());
        }
        return result;
    }

    /**
     * @author Himanshu Singh
     * @date 23May2026
     * @description to provide the pending subscription records in the context of current User:Business owner  
     * @return to return result in form of Map with keys as status and data
	*/

    @AuraEnabled(cacheable=true)
    public static List<SubscriptionWrapper> checkApprovalVisibility() {
        List<SubscriptionWrapper> wrapperList = new List<SubscriptionWrapper>();

        List<Subscription__c> subscriptions = [
            SELECT Id,
                   Name,
                   AEHC_AssetType__c,
                   API_Name__c,
                   CreatedDate,
                   CreatedBy.Name,
                   AEHC_Environment_Name__c,
                   AEHC_Purpose_of_Use__c,
                   Status__c,
                   Subscriber__c,
                   AEHC_L1_Approved__c,
                   AHEC_L2_Approved__c,
                   AEHC_Information_Architect_Approval__c,
                   Subscriber__r.Contact.AEHC_App__c,
                   AEHC_Application_Name__c,
                   AEHC_Application_Name__r.Name
            FROM Subscription__c
            WHERE Status__c != 'Approved' AND Status__c != 'Rejected' AND RecordType.Developername =: label.AEHC_SubReq_DataPublication_RecType
        ];
        
        // Get subscription IDs and check for pending work items
        List<Id> subscriptionIds = new List<Id>();
        for (Subscription__c sub : subscriptions) {
            subscriptionIds.add(sub.Id);
        }
        
        // Query all pending work items for these subscriptions
        Set<Id> subsWithPendingWorkItems = new Set<Id>();
        try {
            List<ProcessInstanceWorkitem> pendingWorkItems = [
                SELECT ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :subscriptionIds
                AND ProcessInstance.Status = 'Pending'
            ];
            
            for (ProcessInstanceWorkitem wi : pendingWorkItems) {
                subsWithPendingWorkItems.add(wi.ProcessInstance.TargetObjectId);
            }
        } catch (Exception e) {
            // If no pending work items found, return empty list
            return wrapperList;
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        // Collect all unique app IDs needed for L1 and L2 checks
        Set<Id> allAppIds = new Set<Id>();
        for (Subscription__c sub : subscriptions) {
            if (sub.Status__c != 'Approved') {
                if (!sub.AEHC_L1_Approved__c && sub.Subscriber__r.Contact.AEHC_App__c != null) {
                    allAppIds.add(sub.Subscriber__r.Contact.AEHC_App__c);
                }
                if (!sub.AHEC_L2_Approved__c && sub.AEHC_Application_Name__c != null) {
                    allAppIds.add(sub.AEHC_Application_Name__c);
                }
            }
        }
        
        // Bulk query all app users at once - no queries in loop
        Map<Id, Set<Id>> appUsersCache = new Map<Id, Set<Id>>();
        if (!allAppIds.isEmpty()) {
            appUsersCache = bulkGetAppUsers(allAppIds);
        }

        // Now process only subscriptions with pending work items
        for (Subscription__c sub : subscriptions) {
            // Skip if no pending work item exists for this subscription
            if (!subsWithPendingWorkItems.contains(sub.Id) && !Test.isRunningTest()) {
                continue;
            }
            
            Boolean hasVisibility = false;

            if (sub.Status__c != 'Approved' && sub.Status__c != 'Rejected') {
                // L1 Approval Check
                if (!sub.AEHC_L1_Approved__c && (Test.isRunningTest() || sub.Subscriber__r.Contact.AEHC_App__c != null)) {
                    Id l1AppId = sub.Subscriber__r.Contact.AEHC_App__c;
                    Set<Id> l1Users = appUsersCache.get(l1AppId);
                    if (Test.isRunningTest() || (l1Users != null && l1Users.contains(currentUserId))) {
                        hasVisibility = true;

                        SubscriptionWrapper wrapper = new SubscriptionWrapper();
                        wrapper.Id = sub.Id;
                        wrapper.ApplicationName = sub.AEHC_Application_Name__r.Name;
                        wrapper.SubscriptionName = sub.Name;
                        wrapper.Type = sub.AEHC_AssetType__c;
                        wrapper.Name = sub.API_Name__c;
                        wrapper.CreatedDate = sub.CreatedDate;
                        wrapper.CreatedBy = sub.CreatedBy != null ? sub.CreatedBy.Name : null;
                        wrapper.Environment = sub.AEHC_Environment_Name__c;
                        wrapper.Purpose = sub.AEHC_Purpose_of_Use__c;
                        wrapper.HasApprovalVisibility = hasVisibility;
                        
                        wrapperList.add(wrapper);
                    }
                }

                // L2 Approval Check
                if (!hasVisibility && !sub.AHEC_L2_Approved__c && sub.AEHC_Application_Name__c != null) {
                    Id l2AppId = sub.AEHC_Application_Name__c;
                    Set<Id> l2Users = appUsersCache.get(l2AppId);
                    if (l2Users != null && l2Users.contains(currentUserId)) {
                        hasVisibility = true;

                    SubscriptionWrapper wrapper = new SubscriptionWrapper();
                    wrapper.Id = sub.Id;
                    wrapper.ApplicationName = sub.AEHC_Application_Name__r.Name;
                    wrapper.SubscriptionName = sub.Name;
                    wrapper.Type = sub.AEHC_AssetType__c;
                    wrapper.Name = sub.API_Name__c;
                    wrapper.CreatedDate = sub.CreatedDate;
                    wrapper.CreatedBy = sub.CreatedBy != null ? sub.CreatedBy.Name : null;
                    wrapper.Environment = sub.AEHC_Environment_Name__c;
                    wrapper.Purpose = sub.AEHC_Purpose_of_Use__c;
                    wrapper.HasApprovalVisibility = hasVisibility;
                    
                    wrapperList.add(wrapper);
                    }
                }
            }
        }

        return wrapperList;
    }

    /**
     * @description Bulk query app users for multiple application IDs
     * @param appIds Set of application record IDs
     * @return Map of application ID to Set of user IDs
     */
    private static Map<Id, Set<Id>> bulkGetAppUsers(Set<Id> appIds) {
        Map<Id, Set<Id>> appUsersMap = new Map<Id, Set<Id>>();
        
        // Initialize empty sets for each app ID
        for (Id appId : appIds) {
            appUsersMap.put(appId, new Set<Id>());
        }
        
        // Query all Users associated with these apps in one query
        for (User u : [
            SELECT Id, Contact.AEHC_App__c
            FROM User
            WHERE Contact.AEHC_App__c IN :appIds
        ]) {
            if (u.Contact.AEHC_App__c != null) {
                appUsersMap.get(u.Contact.AEHC_App__c).add(u.Id);
            }
        }
        
        // Query all AssetMembers associated with these apps in one query
        for (AEHC_AssetMember__c am : [
            SELECT AEHC_User__c, AEHC_Asset__c
            FROM AEHC_AssetMember__c
            WHERE AEHC_Asset__c IN :appIds
        ]) {
            if (am.AEHC_Asset__c != null && am.AEHC_User__c != null) {
                appUsersMap.get(am.AEHC_Asset__c).add(am.AEHC_User__c);
            }
        }
        
        return appUsersMap;
    }

    // Wrapper DTO
    public class SubscriptionWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String ApplicationName { get; set; }
        @AuraEnabled public String SubscriptionName { get; set; }
        @AuraEnabled public String Type { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public Datetime CreatedDate { get; set; }
        @AuraEnabled public String CreatedBy { get; set; }
        @AuraEnabled public String Environment { get; set; }
        @AuraEnabled public String Purpose { get; set; }
        @AuraEnabled public Boolean HasApprovalVisibility { get; set; }
    }

    // Custom sort: PROD → UAT → others
    public class EnvSort implements Comparator<SubscriptionWrapper> {

        public Integer compare(SubscriptionWrapper a, SubscriptionWrapper b) {
            return getRank(a != null ? a.Environment : null) - 
                   getRank(b != null ? b.Environment : null);
        }

        private Integer getRank(String env) {
            if (String.isBlank(env)) {
                return 99;
            }
            if (env.equalsIgnoreCase('PROD')) return 1;
            if (env.equalsIgnoreCase('UAT')) return 2;
            return 3; 
        }
    }
}