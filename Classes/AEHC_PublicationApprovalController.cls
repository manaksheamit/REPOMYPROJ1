public without sharing class AEHC_PublicationApprovalController {
    
     /* =========================================================
       WORK ITEM
    ========================================================== */
    public static boolean isADL = false;
    public class ApprovalRequest {        
        @InvocableVariable
        @AuraEnabled
        public boolean adl;
        
        @InvocableVariable
        @AuraEnabled
        public boolean showapproval;
        
        @InvocableVariable
        @AuraEnabled
        public string schema;
        
        @InvocableVariable
        @AuraEnabled
        public string table;
        
        @InvocableVariable
        @AuraEnabled
        public string selectedApplication;
        
        @AuraEnabled
        public String description;
        
        @AuraEnabled
        public String createdByName;
        
        @AuraEnabled
        public Datetime createdDate;
        
        @AuraEnabled
        public String typeOfChange;
        
        @AuraEnabled
        public Boolean adlReviewRequired;
        
        @AuraEnabled
        public String tabledata;
        
        @AuraEnabled
        public Boolean schemaChange;
        
        @AuraEnabled
        public Boolean scheduleChange;
        
        @AuraEnabled public String scheduleSummary;
        @AuraEnabled public String cronExpression;
        
    }
	public static boolean isSubscriber = false;
    public static ProcessInstanceWorkitem getPendingWorkItem(Id recordId) {
        try {
            return [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                AND ProcessInstance.Status = :Label.AEHC_Pending
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                system.Label.AEHC_NO_record
            );
        }
    }
    
    
    /* =========================================================
       APPROVAL VISIBILITY
    ========================================================== */

    @AuraEnabled
    public static ApprovalRequest checkApprovalVisibility(String recordId,String env) {
        system.debug('recordId'+recordId);
        system.debug(env);
        Boolean recordVisibility = true;
        ApprovalRequest response = new ApprovalRequest();
        
        response.adl = false;
        response.showapproval = false;
        response.schema = '';
        response.table = '';
        response.selectedApplication = '';        
        response.description = '';
        response.createdByName = '';
        response.createdDate = null;
        response.typeOfChange = '';
		response.adlReviewRequired = false;
        response.schemaChange = false;
        response.scheduleChange = false;
        response.scheduleSummary = '';
        response.cronExpression = '';
		if(recordId == null) return response;
        String rectype = Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Version')
                .getRecordTypeId();
        List<AEHC_Asset__c> asset = [
            SELECT Id,AEHC_Subscription_Request__c,
            Approval_Status__c, RecordType.DeveloperName,
            AEHC_Creator_is_L1_Approver__c,
			CreatedBy.Name,
            CreatedDate,
            AEHC_Description__c,
            AEHC_Type_Of_Change__c,AEHC_ADL_Review_Required__c,
            CreatedById,AEHC_Application__c,AEHC_Application__r.Name,
            AEHC_Schedule_Summary__c,AEHC_CRON_Job_Expression__c,  AEHC_Field_Change_Type__c,          
            AEHC_Publication__r.AEHC_Application__c,AEHC_Table_Name__c,AEHC_Schema_Name__c,AEHC_Selected_Fields_JSON__c,AEHC_Is_Fields_Change__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId  AND AEHC_Environment__c =: env and AEHC_Subscription_Request__c = null
                                   order by createdDate  desc limit 1
        ];
        Id currentUserId = UserInfo.getUserId();
        
        /*if(!asset.isEmpty() && getPendingWorkItem(asset[0].Id) != null){
            recordVisibility = true;
            return recordVisibility;
        }*/
        
        Set<Id> userIds = getAppUsers(asset[0]);
        
        if(userIds.contains(currentUserId)  && getPendingWorkItem(asset[0].Id) != null){   
            response.adl = isADL;
        	response.showapproval = true;
        	response.schema = asset[0].AEHC_Schema_Name__c;
        	response.table = asset[0].AEHC_Table_Name__c;
            system.debug(asset[0].AEHC_Application__r.Name);
            response.selectedApplication =  asset[0].AEHC_Application__r.Name;            
            response.description = asset[0].AEHC_Description__c;
            response.createdByName = asset[0].CreatedBy.Name;
            response.createdDate = asset[0].CreatedDate;
            response.typeOfChange = asset[0].AEHC_Type_Of_Change__c;
			response.adlReviewRequired = asset[0].AEHC_ADL_Review_Required__c;
            response.tabledata =  asset[0].AEHC_Selected_Fields_JSON__c;
            response.schemaChange =  asset[0].AEHC_Is_Fields_Change__c;            
            response.scheduleChange = asset[0].AEHC_Field_Change_Type__c != null && asset[0].AEHC_Field_Change_Type__c.contains('Schedule Change');
            response.scheduleSummary = asset[0].AEHC_Schedule_Summary__c;
            response.cronExpression = asset[0].AEHC_CRON_Job_Expression__c;
            
            return response ; 
        }

        if (asset[0].Approval_Status__c == 'Approved') {
            response.adl = false;
        	response.showapproval = false;
        	response.schema = asset[0].AEHC_Schema_Name__c;
        	response.table = asset[0].AEHC_Table_Name__c;
            
            response.selectedApplication =  asset[0].AEHC_Application__r.Name;
            return response ; 
            
        }
  

        return response;
    }
    
    /* =========================================================
       APPROVE / REJECT
    ========================================================== */
    @AuraEnabled
    public static String handleApproval(Id recordId, String action, String comments,String env) {
        string resultStr = 'Error';
        string assetid = '';
        action = ( action == 'Reject' ) ? 'Reject' : 'Approve'; 
        try {
            if (recordId == null) {// if record id null throw exception
               throw new AuraHandledException(system.Label.AEHC_recordId_is_required);
            }
			
        List<AEHC_Asset__c> asset = [
            SELECT Id,
            AEHC_Subscription_Request__c 
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId 
                  AND AEHC_Environment__c =: env AND AEHC_Subscription_Request__c = null 
                                   order by createdDate desc limit 1];
             List<ProcessInstanceWorkitem> piw =new List<ProcessInstanceWorkitem>();
            piw =[ SELECT Id, 
                  Actor.name, 
                  OriginalActorId,
                  ProcessInstance.Status
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId =: asset[0].id order by createddate desc limit 1 ];
            
            if(piw.size() == 0){
                return 'Already Approved';
            }
            ProcessInstanceWorkitem workItem =
                getPendingWorkItem(asset[0].id);
			assetid = asset[0].id;
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItem.Id);
            req.setAction(action);
            req.setComments(comments);

            Approval.ProcessResult result = Approval.process(req);

            if (!result.isSuccess()) {
                throw new AuraHandledException(
                    result.getErrors()[0].getMessage()
                );
            }

        } catch (Exception ex) {
            safeLogException(ex, 'handleApproval-'+action, recordId);
            return 'ERror'+ex.getMessage();
        }
        return 'Success';

    }

     /* =========================================================
       USER FETCH
    ========================================================== */
    public static Set<Id> getAppUsers(AEHC_Asset__c appRecord) {
        try{
            if (appRecord== null) {
                throw new AuraHandledException(system.Label.AEHC_NO_Application);
            }
            Set<Id> userIds = new Set<Id>();
            
		String appID = appRecord.AEHC_Subscription_Request__c != null ?
            appRecord.AEHC_Application__c : appRecord.AEHC_Publication__r.AEHC_Application__c;
            
            String rollVar = getRole(appRecord.Id); 
            if(rollVar == 'DDH Admin' || rollVar == 'Security Architect' ||  rollVar == 'ADL Reviewer' || rollVar == 'Information Architect' )
            {
                for (AEHC_AssetMember__c am : [
                        SELECT AEHC_User__c
                        FROM AEHC_AssetMember__c where
                         AEHC_Role__c  =: rollVar
                    ]) {
                        userIds.add(am.AEHC_User__c);
                    }
            }
            else{
                    for (AEHC_AssetMember__c am : [
                        SELECT AEHC_User__c
                        FROM AEHC_AssetMember__c
                        WHERE  AEHC_Asset__c = :appId 
                        and AEHC_Role__c  =: rollVar
                    ]) {
                        userIds.add(am.AEHC_User__c);
                    }
            }
        return userIds;

        }
        catch (Exception ex) {
            safeLogException(ex, 'getAppUsers', appRecord.Id);
            throw ex;
        }
        
    }
    public static string getRole(String recordId)
    {
        List<ProcessInstanceWorkitem> piw =new List<ProcessInstanceWorkitem>();
            piw =[ SELECT Id, 
                  Actor.name, 
                  OriginalActorId,
                  ProcessInstance.Status
		FROM ProcessInstanceWorkitem
		WHERE ProcessInstance.TargetObjectId =: recordId order by createddate desc limit 1 ];
        String roleVal = '';
        if(piw.size() > 0){
        if(piw[0].Actor.name == 'DDH Admin')        {            roleVal = 'DDH Admin';                  }
        else if(piw[0].Actor.name == 'Publication Business Owner' )        {            roleVal = 'Business Owner';        }
            else if(piw[0].Actor.name == 'Subscriber Business Owner' )        {            roleVal = 'Business Owner';            isSubscriber =true;        }
        else if(piw[0].Actor.name == 'Security Architect' )        {            roleVal = 'Security Architect';        }
            else if(piw[0].Actor.name == 'ADL Approver' )        {            roleVal = 'ADL Reviewer';   isADL = true;     }
            else if(piw[0].Actor.name == 'Information Architect Review' )        {            roleVal = 'Information Architect';         }
        return roleVal;
        }        else            return null;
    }
    
     /* =========================================================
       LOGGING
    ========================================================== */

    private static void safeLogException(Exception ex,
                                         String operation,
                                         Id recordId) {
        try {
            AEHC_Logger.logException(
                ex,
                'Apex',
                'AEHC_SubscriptionApprovalController',
                operation,
                recordId != null ? String.valueOf(recordId) : null,
                'High',
                'SubscriptionApproval',
                null,
                'UAT'
            );
        } catch (Exception ignore) {}
    }
}