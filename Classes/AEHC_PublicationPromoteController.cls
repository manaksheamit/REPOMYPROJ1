public with sharing class AEHC_PublicationPromoteController {

    public class PromoteStatusDTO {
        @AuraEnabled public AEHC_Asset__c publication;
        @AuraEnabled public Boolean hasPendingVersion;
        @AuraEnabled public Boolean hasAccess; 
        @AuraEnabled public Boolean hasSameVersion; 
        @AuraEnabled public Boolean approvalPermission;
    }
	@AuraEnabled(cacheable=true)
	public static Boolean isRecordPendingApproval(Id subscriptionId,String env) {
        try{
    	if (subscriptionId == null) return false;
        List<AEHC_Asset__c> pubList = new List<AEHC_Asset__c>();
        pubList = [
            SELECT Id,
                   Name,
                   Approval_Status__c,
                   AEHC_Environment__c,
                   AEHC_Publication__c,
                   AEHC_Application__c,
            		AEHC_Is_Active__c,AEHC_Schema_Version__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :subscriptionId and AEHC_Environment__c =: env and AEHC_Is_Active__c = true
            LIMIT 1
        ];
        string nextEnv = getNextEnvironment( pubList[0].AEHC_Environment__c);
		List<AEHC_Asset__c> hasPending = new List<AEHC_Asset__c>();
        hasPending = [
            SELECT id
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :subscriptionId And AEHC_Environment__c = : nextEnv 
            AND Approval_Status__c = 'Pending'
        ];
        
        return [
            SELECT COUNT()
            FROM ProcessInstance
            WHERE TargetObjectId = :hasPending[0].id
            AND Status = 'Pending'
        ] > 0;
        }catch(Exception ex)
        {
            return false;
        }
        
	}
    
    @AuraEnabled
    public static String processApprovalAction(
        Id recordId,
        String action,
        String comments,String env
    ) {
        if (recordId == null) return 'Invalid record';
        
        List<AEHC_Asset__c> pubList = new List<AEHC_Asset__c>();
        pubList = [
            SELECT Id,
                   Name,
                   Approval_Status__c,
                   AEHC_Environment__c,
                   AEHC_Publication__c,
                   AEHC_Application__c,
            		AEHC_Is_Active__c,AEHC_Schema_Version__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c =: env and AEHC_Is_Active__c = true
            LIMIT 1
        ];
        string nextEnv = getNextEnvironment( pubList[0].AEHC_Environment__c);
		List<AEHC_Asset__c> hasPending = new List<AEHC_Asset__c>();
        hasPending = [
            SELECT id
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId And AEHC_Environment__c = : nextEnv 
            AND Approval_Status__c = 'Pending'
        ];
        
        // Get pending work item
        ProcessInstanceWorkitem workItem = [
            SELECT Id, ProcessInstanceId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :hasPending[0].id
            LIMIT 1
        ];
        
        // Prepare request
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItem.Id);
        req.setComments(comments);
        
        if (action == 'Promote') {
            req.setAction('Approve');
        } else {
            req.setAction('Reject');
        }
        
        Approval.ProcessResult result = Approval.process(req);
        
        if (result.isSuccess()) {
            return 'SUCCESS';
        } else {
            return 'FAILED';
        }
    }
    @AuraEnabled(cacheable=true)
    public static PromoteStatusDTO getPromotionStatus(Id recordId,String env) {

        system.debug(env);
        PromoteStatusDTO dto = new PromoteStatusDTO();
        List<AEHC_Asset__c> pubList = new List<AEHC_Asset__c>();
        pubList = [
            SELECT Id,
                   Name,
                   Approval_Status__c,
                   AEHC_Environment__c,
                   AEHC_Publication__c,
                   AEHC_Application__c,
            		AEHC_Is_Active__c,AEHC_Schema_Version__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c =: env order by createdDate desc
            LIMIT 1
        ];
		if(pubList.size() > 0)
        {
        Id rootPublicationId =
            pubList[0].AEHC_Publication__c != null ? pubList[0].AEHC_Publication__c : pubList[0].Id;
		string nextEnv = getNextEnvironment( pubList[0].AEHC_Environment__c);
        
        Boolean hasPending = [
            SELECT COUNT()
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :rootPublicationId And AEHC_Environment__c = : nextEnv 
            AND Approval_Status__c in ('Business Owner Subscriber Review','Business Owner Publication Review','Security Architect Review','DDH Admin Review')
                                      ] > 0;
		Boolean hasSameVersion = [
            SELECT COUNT()
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :rootPublicationId And AEHC_Environment__c = : nextEnv AND AEHC_Schema_Version__c =: pubList[0].AEHC_Schema_Version__c 
            and Approval_Status__c != 'Rejected'
        ] > 0;
        /*  NEW: USER ACCESS CHECK */
        List<AEHC_AssetMember__c> members = [
            SELECT AEHC_Role__c
            FROM AEHC_AssetMember__c
            WHERE AEHC_Asset__c = :pubList[0].AEHC_Application__c
            AND AEHC_User__c = :UserInfo.getUserId()
            LIMIT 1
        ];

        Boolean hasAccess = false;
		Boolean approvalPermission = false;
        USer u = [Select id,AEHC_User_Persona__c from user where id =: UserInfo.getUserId()];
            system.debug(u);
            if ( u.AEHC_User_Persona__c == 'Business Owner' ||  u.AEHC_User_Persona__c == 'Developer'  ) {
                hasAccess = true;
            }
           
        if (!members.isEmpty()) {
            String role = members[0].AEHC_Role__c;
			//hasAccess = true;
            if (role == 'Business Owner' || u.AEHC_User_Persona__c == 'Business Owner' ||  u.AEHC_User_Persona__c == 'Developer' || role == 'Developer' || role == 'Admin' ) {
                hasAccess = true;
            }
             if (role == 'Business Owner' || role == 'DDH Admin') {
                
                approvalPermission = true;
            }
        }

		
            
        dto.publication = pubList[0];
        dto.hasPendingVersion = hasPending;
        dto.hasAccess = hasAccess; 
        dto.hasSameVersion = hasSameVersion;
        dto.approvalPermission = approvalPermission;
        return dto;
        }
        else{
            
        }
        dto.publication = null;
        dto.hasPendingVersion = null;
        dto.hasAccess = null;
        return dto;
    }

    @AuraEnabled
    public static Id promotePublication(Id recordId,string env) {

        AEHC_Asset__c pub = [
            SELECT Id,Name,
                   Approval_Status__c,
                   AEHC_Environment__c,
                   AEHC_Publication__c,AEHC_Application__c,
            	   AEHC_Account__c,AEHC_Schedule_Summary__c,
            		AEHC_Schema_Version__c,
             	   AEHC_Selected_Fields__c,
    			   AEHC_Selected_Fields_JSON__c,
    				AEHC_Is_Active__c,
    				AEHC_Publication_Description__c,
    				AEHC_Publication_Id__c,
    				AEHC_Publication_Type__c,
    				AEHC_Schedule__c,    AEHC_Schema__c,
    				AEHC_Schema_Name__c,AEHC_CRON_Job_Expression__c,
    				AEHC_Table_Name__c,
            		AEHC_Application__r.Name,
            		AEHC_Publication__r.Name,
            		AEHC_Time__c,AEHC_Weekdays__c,AEHC_Weeks__c,AEHC_Day_of_Month__c,AEHC_One_Time_Execution_Time__c,AEHC_One_Time_Execution_Date__c,
            		AEHC_Frequency__c,
            		AEHC_VSchedule__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c =: env  and AEHC_Is_Active__c = true and AEHC_Is_Subscription__c = false
            LIMIT 1
        ];
		AEHC_Asset__c pubToClone = [
            SELECT Id,Name,
                   Approval_Status__c,
                   AEHC_Environment__c,
                   AEHC_Publication__c,AEHC_Application__c,
            	   AEHC_Account__c,AEHC_Schedule_Summary__c,
            	   AEHC_Schema_Version__c,
             	   AEHC_Selected_Fields__c,
    			   AEHC_Selected_Fields_JSON__c,
    				AEHC_Is_Active__c,
    				AEHC_Publication_Description__c,
    				AEHC_Publication_Id__c,
    				AEHC_Publication_Type__c,
    				AEHC_Schedule__c,    AEHC_Schema__c,
    				AEHC_Schema_Name__c,AEHC_CRON_Job_Expression__c,
    				AEHC_Table_Name__c,
            		AEHC_Time__c,AEHC_Weekdays__c,AEHC_Weeks__c,AEHC_Day_of_Month__c,AEHC_One_Time_Execution_Time__c,AEHC_One_Time_Execution_Date__c,
            		AEHC_Frequency__c,
            		AEHC_VSchedule__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c =: env  and AEHC_Is_Active__c = true and AEHC_Is_Subscription__c = false
            LIMIT 1
        ];

        AEHC_Asset__c newVersion = pubToClone.clone(false, true, false, false);

        newVersion.AEHC_Environment__c = getNextEnvironment(pub.AEHC_Environment__c);
        //newVersion.Approval_Status__c = 'Business Owner Publication Review';
        //newVersion.AEHC_Field_Change_Type__c = 'Schedule Change';
        //newVersion.AEHC_Is_Fields_Change__c = true;
        
           
		newVersion.Name = AEHC_PublicationSubRequestController.buildVersionName(pub.AEHC_Application__r.Name,
                                                                                pub.AEHC_Publication__r.Name,
                                                                                newVersion.AEHC_Environment__c,
                                                                                pub.AEHC_Schema_Version__c);
        newVersion.Approval_Status__c = (newVersion.AEHC_Environment__c == 'QA' || newVersion.AEHC_Environment__c == 'Production') ?'DDH Admin Review':'Pending';
        
        if(newVersion.AEHC_Environment__c == 'UAT' )
        {
            newVersion.Approval_Status__c = 'Security Architect Review';
        }
        
        newVersion.AEHC_Is_Active__c = false;
        if(newVersion.AEHC_Schema_Version__c != '1'){
            newVersion.AEHC_IntId__c=AEHC_PublicationSubRequestController.getIntId(pub.AEHC_Application__c, pub.Id, newVersion.AEHC_Environment__c,'1', false, null);
        }
        
        newVersion.RecordTypeId =
            Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Version')
                .getRecordTypeId();

        insert newVersion;
        return newVersion.Id;
    }

    public static String getNextEnvironment(String env) {
        switch on env {
            when 'Dev' { return 'QA'; }
            when 'QA' { return 'UAT'; }
            when 'UAT' { return 'Production'; }
            when else { return null; }
        }
    }
}