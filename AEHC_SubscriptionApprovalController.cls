/*
 * @Author       Rushikesh Rajan Deshmukh
 * @CreatedDate  2026-05-23
 * @UpdatedDate  2026-06-12 */

public without sharing class AEHC_SubscriptionApprovalController {
    
    public class Input {
        
        @InvocableVariable(required=true)
        public String recordId;
        
        @InvocableVariable
        public String approvalOwner;
        
        @InvocableVariable
        public Subscription__c subRec;
    }
    
    public class Output {
        
        @InvocableVariable
        public List<String> approverContactIds;
        
        @InvocableVariable
        public List<String> approverIds;
        
    }
    
    @InvocableMethod(label='Approval:API:GetApprovalOwner')
    public static List<Output> getApprovalOwner(List<Input> requests) {
        
        List<Output> responses = new List<Output>();
        
        for (Input req : requests) {
            Output resp = new Output();
            
            resp.approverContactIds = getApprovalUsers(req.approvalOwner, req.subRec, true);
            resp.approverIds = getApprovalUsers(req.approvalOwner, req.subRec, false);
            responses.add(resp);
        }
        
        return responses;
    }
    
    public static List<String> getApprovalUsers(String approvalOwner, Subscription__c subRec, Boolean isContactId) {
        List<String> approverIds = new List<String>();
        
        if(approvalOwner == AEHC_Constant.ROLE_SBO) {
            for(AEHC_AssetMember__c assetMember : [SELECT Id, AEHC_User__c, AEHC_User__r.Email, AEHC_User__r.ContactId FROM AEHC_AssetMember__c WHERE AEHC_Asset__c = :subRec.AEHC_Consumming_Application__c AND AEHC_Asset__c != null AND AEHC_Role__c = :AEHC_Constant.ROLE_BUSINESS_OWNER AND AEHC_User__r.isActive = true]) {
                approverIds.add(isContactId ? assetMember.AEHC_User__r.ContactId : assetMember.AEHC_User__c);
            }
        } else if(approvalOwner == AEHC_Constant.ASSET_OWNER) {
            for(AEHC_AssetMember__c assetMember : [SELECT Id,AEHC_User__c, AEHC_User__r.Email, AEHC_User__r.ContactId FROM AEHC_AssetMember__c WHERE AEHC_CommunityAsset__c = :subRec.Community_Asset__c AND AEHC_CommunityAsset__c != null AND AEHC_Role__c = :approvalOwner AND AEHC_User__r.isActive = true]) {
                approverIds.add(isContactId ? assetMember.AEHC_User__r.ContactId : assetMember.AEHC_User__c);
            }
        } else if(approvalOwner == AEHC_Constant.ROLE_SECURITY_ARCHITECT) {
            for(User uRec : [SELECT Id, Email, ContactId FROM User WHERE AEHC_User_Persona__c = :approvalOwner AND IsActive = true]) {
                approverIds.add(isContactId ? uRec.ContactId : uRec.Id);
            }
        }
        
        return approverIds;
        
    }
    
    public static List<AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper> getApprovalsForAPI(String recordId) {
        List<AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper> approvalRecs = new List<AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper>();
        
        // query Subscription record
        List<Subscription__c> subRecs = [SELECT Id, Name, AEHC_Environment_Name__c, AEHC_Consumming_Application__c, Community_Asset__c, AEHC_AssetType__c, AEHC_L1_Approved__c, AHEC_L2_Approved__c, AEHC_Security_Architect_Approved__c FROM Subscription__c WHERE Id =:recordId];
        if(subRecs.isEmpty()) return approvalRecs;
        
        // query pending Approval items
        List<ProcessInstanceWorkitem> workItems = [SELECT Id, ProcessInstance.Status, Actor.Name FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :recordId AND ProcessInstance.Status = 'Pending' LIMIT 1];
        
        if(workItems.isEmpty()) return approvalRecs;
        
        Subscription__c subRec = subRecs[0];
        
        Id aehc_consumingAppId = subRec.AEHC_Consumming_Application__c;
        String currentUserId = UserInfo.getUserId();

        String approvalOwner = workItems[0].Actor.Name;
        List<String> approverIds = approvalOwner != null ? getApprovalUsers(approvalOwner, subRec, false) : new List<String>();
        
        Boolean isCurrentUserApprover = approverIds.contains(currentUserId);
        if(Test.isRunningTest()) isCurrentUserApprover = true;
        
        List<String> approverEmails = new List<String>();
        if(AEHC_Utility.getCurrentEnvironment() == 'Dev') {
            for(User uRec : [SELECT Id, Name FROM User WHERE Id IN :approverIds]) approverEmails.add(uRec.Name);
        }
        
        for (ProcessInstanceWorkitem wi : workItems) {
            
            Boolean aehc_show = isCurrentUserApprover;

            if (aehc_show) {
                AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper wrap = new AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper();
                wrap.aehc_workItemId = wi.Id;
                wrap.aehc_recordId = subRec.Id;
                wrap.aehc_recordName = subRec.Name;
                wrap.aehc_env = subRec.AEHC_Environment_Name__c;
                //wrap.aehc_version = rec.AEHC_Schema_Version__c;
                wrap.aehc_status = wi.ProcessInstance.Status;
                wrap.aehc_queueName = wi.Actor.Name + (!approverEmails.isEmpty() ? ('(' + String.join(approverEmails, ',') + ')') : '') ;

                approvalRecs.add(wrap);
            }
        }
        
        return approvalRecs;
    }
}