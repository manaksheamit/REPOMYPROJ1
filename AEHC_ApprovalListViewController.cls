public with sharing class AEHC_ApprovalListViewController {
    
    /** RESPONSE*/
    public class ApprovalResponse {
        @AuraEnabled
        public List<ApprovalWrapperResponse> records = new List<ApprovalWrapperResponse>();
    }
    
    public class ApprovalWrapperResponse {
        @AuraEnabled public String name;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Boolean isSubscription;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String assetType;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public String schemaName;
        @AuraEnabled public String tableName;
        @AuraEnabled public String processStatus;
        @AuraEnabled public String environment;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String queueName;
        @AuraEnabled public String navigationUrl;
    }
    
    @AuraEnabled(cacheable=true)
    public static ApprovalResponse getApprovalData(String requestType, String status) {
        
        ApprovalResponse response = new ApprovalResponse();
        
        try {
            System.debug('========== START ==========');
            System.debug('Request Type = ' +requestType);
            System.debug('Status = ' + status);
            
            if(String.isBlank(status) || !new Set<String>{'Pending', 'Approved', 'Rejected'}.contains(status)) {
                status = 'Pending';
            }
            
            if(status == 'Approved' || status == 'Rejected') {
                return getCompletedApprovalData(requestType, status);
            }
            
            /** ASSET MEMBER*/
            List<AEHC_AssetMember__c> assetMembers = [SELECT AEHC_Role__c, AEHC_Asset__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :UserInfo.getUserId()];
            
            Set<String> userRoles = new Set<String>();
            Map<String, Set<Id>> roleToApplications = new Map<String, Set<Id>>();
            for(AEHC_AssetMember__c member : assetMembers) {
                
                if(String.isNotBlank(member.AEHC_Role__c)) {
                    userRoles.add(member.AEHC_Role__c);
                    
                    if(!roleToApplications.containsKey(member.AEHC_Role__c)) {
                        roleToApplications.put(member.AEHC_Role__c, new Set<Id>());
                    }
                }
                
                if(member.AEHC_Asset__c != null && String.isNotBlank(member.AEHC_Role__c)) {
                    roleToApplications.get(member.AEHC_Role__c).add(member.AEHC_Asset__c);
                }
            }
            
            System.debug('Roles => ' + userRoles);
            System.debug('Role To Applications => ' + roleToApplications);
            
            Set<Id> businessOwnerApps = roleToApplications.containsKey('Business Owner')
                ? roleToApplications.get('Business Owner')
                : new Set<Id>();
            
            System.debug('Business Owner Apps => ' + businessOwnerApps);
            
            /** QUEUES*/
            Set<String> queueNames = new Set<String>();
            
            if(requestType == 'APPROVAL') {
                
                if(userRoles.contains('Security Architect')) {
                    queueNames.add('Security Architect');
                }
                
                if(userRoles.contains('Asset Owner')) {
                    queueNames.add('Asset Owner');
                }
                
                if(userRoles.contains('Information Architect')) {
                    queueNames.add('Information Architect Review');
                }
                
                if(userRoles.contains('Business Owner')) {
                    queueNames.add('Subscriber Business Owner');
                    queueNames.add('Publication Business Owner');
                }
                
            }
            else if(requestType == 'PROMOTION') {
                if(userRoles.contains('DDH Admin')) {
                    queueNames.add('DDH Admin');
                }
            }
            else if(requestType == 'SCHEMA') {
                if(userRoles.contains('ADL Reviewer')) {
                    queueNames.add('ADL Approver');
                }
            }
            
            System.debug('Queue Names => ' + queueNames);
            
            if(queueNames.isEmpty()) {
                System.debug('No matching queue.');
                return response;
            }
            
            /** WORK ITEMS*/
            List<ProcessInstanceWorkitem>
                workItems = [SELECT Id, ProcessInstanceId, OriginalActor.Name, CreatedDate, ProcessInstance.Status, ProcessInstance.TargetObjectId, ProcessInstance.TargetObject.Type
                             FROM ProcessInstanceWorkitem WHERE ProcessInstance.Status = :status ORDER BY CreatedDate DESC];
            
            System.debug('WorkItem Count=' + workItems.size());
            
            Map<Id, ProcessInstanceWorkitem> latestMap = new Map<Id, ProcessInstanceWorkitem>();
            
            for(ProcessInstanceWorkitem wi : workItems) {
                if(!latestMap.containsKey(wi.ProcessInstanceId)) {
                    latestMap.put(wi.ProcessInstanceId,wi);
                }
            }
            
            System.debug('Latest Map Count=' + latestMap.size());
            
            Set<Id> subscriptionIds = new Set<Id>();
            
            Set<Id> assetIds = new Set<Id>();
            
            Map<Id, ProcessInstanceWorkitem> subscriptionMap = new Map<Id, ProcessInstanceWorkitem>();
            
            Map<Id, ProcessInstanceWorkitem> assetMap = new Map<Id, ProcessInstanceWorkitem>();
            
            for(ProcessInstanceWorkitem wi : latestMap.values()) {
                
                if(wi.ProcessInstance.TargetObject.Type == 'Subscription__c') {
                    subscriptionIds.add(wi.ProcessInstance.TargetObjectId);
                    subscriptionMap.put(wi.ProcessInstance.TargetObjectId, wi);
                }
                else if(wi.ProcessInstance.TargetObject.Type == 'AEHC_Asset__c') {
                    assetIds.add(wi.ProcessInstance.TargetObjectId);
                    assetMap.put(wi.ProcessInstance.TargetObjectId, wi);
                }
            }
            
            System.debug('Subscription Ids=' +subscriptionIds.size());
            System.debug('Asset Ids=' + assetIds.size());

            //reacord Visibility Check
            Map<Id, UserRecordAccess> accessMap = new Map<Id, UserRecordAccess>([
            SELECT RecordId, HasReadAccess FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId IN :subscriptionIds]);
            
            /** SUBSCRIPTIONS*/
            //add null check for subscriptionMap get key set
            for(Subscription__c sub : [SELECT Id, Name, CreatedDate, CreatedBy.Name, AEHC_AssetType__c, AEHC_Environment_Name__c, AEHC_Application_Name__c, AEHC_Consumming_Application__c, 
                                       AEHC_Consumming_Application__r.Name, AEHC_Schema_Version__c, Status__c FROM Subscription__c WHERE Id IN :subscriptionIds]) {
                                           
                                           ProcessInstanceWorkitem wi = subscriptionMap.get(sub.Id);
                                           
                                           if(wi == null) {
                                               continue;
                                           }
                                           if(!accessMap.containsKey(sub.Id) || !accessMap.get(sub.Id).HasReadAccess){
                                                continue;
                                            }
                                           
                                           String queueName = getQueueName(wi);
                                           
                                           if (!queueNames.contains(queueName)) {
                                               continue;
                                           }
                                           
                                           Boolean shouldInclude = true;
                                           
                                           if(queueName == 'Subscriber Business Owner') {
                                               shouldInclude = businessOwnerApps.contains(sub.AEHC_Consumming_Application__c);
                                           }
                                           
                                           if(!shouldInclude) {
                                               //System.debug('Skipping Subscription=' + sub.Id + ' Queue=' +queueName);
                                               continue;
                                           }
                                           
                                           ApprovalWrapperResponse row = new ApprovalWrapperResponse();
                                           
                                           row.processStatus = wi.ProcessInstance.Status;
                                           row.recordId = sub.Id;
                                           row.name = sub.Name;
                                           row.assetType = sub.AEHC_AssetType__c;
                                           row.environment = sub.AEHC_Environment_Name__c;
                                           row.createdDate = sub.CreatedDate;
                                           row.approvalStatus = sub.Status__c;
                                           row.createdByName = sub.CreatedBy.Name;
                                           row.schemaVersion = sub.AEHC_Schema_Version__c;
                                           row.queueName = wi.OriginalActor.Name;
                                           row.navigationUrl ='/manage-subscriptions?subscriptionId='+sub.Id;
                                           response.records.add(row);
                                       }
            
            /** ASSETS*/
            //add null check for assetMap get key set
            for(AEHC_Asset__c asset : [SELECT Id, CreatedDate, CreatedBy.Name, AEHC_Schema_Name__c, AEHC_Table_Name__c, AEHC_Environment__c,Approval_Status__c,
                                       AEHC_Is_Subscription__c,AEHC_Publication__c,AEHC_Publication__r.Name,AEHC_Publication__r.AEHC_Publication_Type__c,AEHC_Publication__r.AEHC_Application__c, AEHC_Subscription_Request__c,
                                       AEHC_Subscription_Request__r.AEHC_Consumming_Application__c, AEHC_Subscription_Request__r.Name, AEHC_Publication__r.AEHC_Publication_Id__c FROM AEHC_Asset__c
                                       WHERE Id IN :assetIds]) {
                                           
                                           ProcessInstanceWorkitem wi = assetMap.get(asset.Id);
                                           if(wi == null) {
                                               continue;
                                           }
                                           
                                           ApprovalWrapperResponse row = new ApprovalWrapperResponse();
                                           Boolean shouldIncludeAsset = true;
                                           String queueNameAsset = getQueueName(wi);
                                           if (!queueNames.contains(queueNameAsset)) {
                                               continue;
                                           }
                                           if(asset.AEHC_Is_Subscription__c == true) { // for subscriptions
                                               if(queueNameAsset == 'Publication Business Owner') {
                                                   shouldIncludeAsset = businessOwnerApps.contains(asset.AEHC_Publication__r.AEHC_Application__c);
                                               } else if(queueNameAsset =='Subscriber Business Owner') {
                                                   shouldIncludeAsset = businessOwnerApps.contains(asset.AEHC_Subscription_Request__r.AEHC_Consumming_Application__c);
                                               }
                                           }
                                           else {// for publications
                                               if(queueNameAsset == 'Publication Business Owner') {
                                                   shouldIncludeAsset = businessOwnerApps.contains(asset.AEHC_Publication__r.AEHC_Application__c);
                                               }
                                           }
                                           
                                           if(!shouldIncludeAsset) {
                                               System.debug('Skipping Asset=' + asset.Id + ' Queue=' + queueNameAsset);
                                               continue;
                                           }
                                           
                                           row.processStatus = wi.ProcessInstance.Status;
                                           row.recordId = asset.Id;
                                           row.schemaName = asset.AEHC_Schema_Name__c;
                                           row.tableName = asset.AEHC_Table_Name__c;
                                           row.environment = asset.AEHC_Environment__c;
                                           row.approvalStatus = asset.Approval_Status__c;
                                           row.isSubscription = asset.AEHC_Is_Subscription__c;
                                           row.createdDate = asset.CreatedDate;
                                           row.createdByName = asset.CreatedBy.Name;
                                           row.queueName = queueNameAsset;
                                           String env = String.isBlank(asset.AEHC_Environment__c) ? 'Dev' : EncodingUtil.urlEncode(asset.AEHC_Environment__c, 'UTF-8');
                                           String version = String.isBlank(asset.AEHC_Schema_Name__c) ? '1' : EncodingUtil.urlEncode(asset.AEHC_Schema_Name__c,'UTF-8');
                                           if(asset.AEHC_Is_Subscription__c) {
                                               row.name = asset.AEHC_Subscription_Request__r.Name; //add code
                                               row.assetType = asset.AEHC_Publication__r.AEHC_Publication_Type__c; //cadd code
                                               row.navigationUrl ='/manage-subscriptions?subscriptionId=' + asset.AEHC_Subscription_Request__c +
                                                   '&env=' + env +
                                                   '&ver=' + version;
                                           } else {
                                               row.name = asset.AEHC_Publication__r.AEHC_Publication_Id__c; //add code
                                               row.assetType = 'Publication '+asset.AEHC_Publication__r.AEHC_Publication_Type__c; //cadd code
                                               row.navigationUrl = '/data-publication-details?id=' + asset.AEHC_Publication__c +
                                                   '&env=' + env;
                                           }
                                           response.records.add(row);
                                       }
            
            System.debug('Result=' + response.records.size());
            //System.debug(JSON.serializePretty(response));
            System.debug('========== END ==========');
            
            return response;
            
        } catch(Exception ex) {
            System.debug('ERROR => ' + ex.getMessage());
            System.debug(ex.getStackTraceString());
            throw new AuraHandledException(ex.getMessage());
        }
    }
    private static ApprovalResponse getCompletedApprovalData(String requestType, String status) {
        
        ApprovalResponse response = new ApprovalResponse();
        
        List<ProcessInstance> processes = [SELECT Id, Status, TargetObjectId, TargetObject.Name, TargetObject.Type, LastModifiedById, LastModifiedBy.Name FROM ProcessInstance
                                           WHERE Status = :status AND LastModifiedById = :UserInfo.getUserId()
                                           AND ((TargetObject.Type = 'AEHC_Asset__c') OR (TargetObject.Type = 'Subscription__c'))
                                           ORDER BY CreatedDate DESC];
        
        System.debug('Completed Processes=' + processes.size());
        
        Set<Id> subscriptionIds = new Set<Id>();
        Set<Id> assetIds = new Set<Id>();
        
        Map<Id, ProcessInstance> subPIMap = new Map<Id, ProcessInstance>();
        Map<Id, ProcessInstance> assetPIMap = new Map<Id, ProcessInstance>();
        
        for(ProcessInstance pi : processes) {
            
            if(pi.TargetObject.Type == 'Subscription__c') {
                subscriptionIds.add(pi.TargetObjectId);
                subPIMap.put(pi.TargetObjectId, pi);
            } else if(pi.TargetObject.Type == 'AEHC_Asset__c') {
                assetIds.add(pi.TargetObjectId);
                assetPIMap.put(pi.TargetObjectId,pi);
            }
        }
        Map<Id, UserRecordAccess> accessMap =
    new Map<Id, UserRecordAccess>(
        [
            SELECT RecordId,
                   HasReadAccess
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId()
            AND RecordId IN :subscriptionIds
        ]
    );
        
        /** SUBSCRIPTIONS*/
        if(!subscriptionIds.isEmpty()) {
            
            for(Subscription__c sub : [SELECT Id,Name,CreatedDate, CreatedBy.Name, AEHC_AssetType__c, AEHC_Environment_Name__c, AEHC_Application_Name__c, 
                                       AEHC_Consumming_Application__c, AEHC_Consumming_Application__r.Name, AEHC_Schema_Version__c, Status__c FROM Subscription__c WHERE Id IN :subscriptionIds]) {
                                           ProcessInstance pi = subPIMap.get(sub.Id);
                                           if(pi == null) {
                                               continue;
                                           }
                                           if(!accessMap.containsKey(sub.Id) || !accessMap.get(sub.Id).HasReadAccess){
                continue;
            }
                                           
                                           ApprovalWrapperResponse row = new ApprovalWrapperResponse();
                                           row.processStatus = pi.Status;
                                           row.recordId = sub.Id;
                                           row.name = sub.Name;
                                           row.assetType = sub.AEHC_AssetType__c;
                                           row.environment = sub.AEHC_Environment_Name__c;
                                           row.createdDate = sub.CreatedDate;
                                           row.approvalStatus = sub.Status__c;
                                           row.createdByName = sub.CreatedBy.Name;
                                           row.schemaVersion = sub.AEHC_Schema_Version__c;
                                           row.navigationUrl = '/manage-subscriptions?subscriptionId=' + sub.Id;
                                           row.queueName = 'Completed';
                                           
                                           response.records.add(row);
                                       }
        }
        
        /** ASSETS*/
        if(!assetIds.isEmpty()) {
            
            for(AEHC_Asset__c asset : [SELECT Id, CreatedDate, CreatedBy.Name, AEHC_Schema_Name__c, AEHC_Table_Name__c, AEHC_Environment__c, Approval_Status__c, 
                                       AEHC_Is_Subscription__c, AEHC_Publication__c, AEHC_Publication__r.Name, AEHC_Publication__r.AEHC_Publication_Type__c, AEHC_Subscription_Request__c,
                                       AEHC_Subscription_Request__r.Name, AEHC_Publication__r.AEHC_Publication_Id__c FROM AEHC_Asset__c WHERE Id IN :assetIds]) {
                                           
                                           ProcessInstance pi = assetPIMap.get(asset.Id);
                                           
                                           if(pi == null) {
                                               continue;
                                           }
                                           
                                           ApprovalWrapperResponse row = new ApprovalWrapperResponse();
                                           row.processStatus = pi.Status;
                                           row.recordId = asset.Id;
                                           row.schemaName = asset.AEHC_Schema_Name__c;
                                           row.tableName = asset.AEHC_Table_Name__c;
                                           row.environment = asset.AEHC_Environment__c;
                                           row.approvalStatus = asset.Approval_Status__c;
                                           row.isSubscription = asset.AEHC_Is_Subscription__c;
                                           if(asset.AEHC_Is_Subscription__c == true){
                                               row.name = asset.AEHC_Subscription_Request__r.Name; //add code
                                               row.assetType = asset.AEHC_Publication__r.AEHC_Publication_Type__c; //cadd code
                                           } else {
                                               row.name = asset.AEHC_Publication__r.AEHC_Publication_Id__c; //add code
                                               row.assetType = 'Publication '+asset.AEHC_Publication__r.AEHC_Publication_Type__c; //cadd code
                                           }
                                           row.createdDate = asset.CreatedDate;
                                           row.createdByName = asset.CreatedBy.Name;
                                           String env = String.isBlank(asset.AEHC_Environment__c) ? 'Dev' : EncodingUtil.urlEncode(asset.AEHC_Environment__c, 'UTF-8');
                                           String version = String.isBlank(asset.AEHC_Schema_Name__c) ? '1' : EncodingUtil.urlEncode(asset.AEHC_Schema_Name__c,'UTF-8');
                                           if(asset.AEHC_Is_Subscription__c && pi.Status == 'Rejected') {
                                               row.navigationUrl ='/manage-subscriptions?subscriptionId=' + asset.AEHC_Subscription_Request__c +
                                                   '&env=' + env +
                                                   '&ver=' + version;
                                           } else if(asset.AEHC_Is_Subscription__c && pi.Status != 'Rejected') {
                                               row.navigationUrl = '/manage-subscriptions?subscriptionId=' + asset.AEHC_Subscription_Request__c;
                                           } else if(!asset.AEHC_Is_Subscription__c && pi.Status == 'Rejected') {
                                               row.navigationUrl = '/data-publication-details?id=' + asset.AEHC_Publication__c +
                                                   '&env=' + env;
                                           } else {
                                               row.navigationUrl = '/data-publication-details?id=' + asset.AEHC_Publication__c;
                                           }
                                           row.queueName = 'Completed';
                                           
                                           response.records.add(row);
                                       }
        }
        
        return response;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableRequestTypes() {
        
        Set<String> requestTypes = new Set<String>();
        
        List<AEHC_AssetMember__c> assetMembers = [SELECT AEHC_Role__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :UserInfo.getUserId()];
        
        Set<String> roles = new Set<String>();
        
        for(AEHC_AssetMember__c member : assetMembers) {
            
            if(String.isNotBlank(member.AEHC_Role__c)) {
                roles.add(member.AEHC_Role__c);
            }
        }
        
        /** APPROVAL*/
        if(roles.contains('Business Owner') || roles.contains('Security Architect') || roles.contains('Asset Owner') || roles.contains('Information Architect')) {
            requestTypes.add('APPROVAL');
        }
        
        /** PROMOTION*/
        if(roles.contains('DDH Admin')) {
            requestTypes.add('PROMOTION');
        }
        
        /** SCHEMA*/
        if(roles.contains('ADL Reviewer')) {
            requestTypes.add('SCHEMA');
        }
        
        return new List<String>(requestTypes);
    }
    private static String getQueueName(ProcessInstanceWorkitem wi) {
        return wi != null && wi.OriginalActor != null
            ? wi.OriginalActor.Name
            : '';
    }
}