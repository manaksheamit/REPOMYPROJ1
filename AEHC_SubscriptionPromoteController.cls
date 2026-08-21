/**
 * @description
 * Controller responsible for validating and promoting Subscription records
 * across environments (Dev → QA → UAT → PROD).
 *
 * Responsibilities:
 * 1. Validate eligibility (status, access, duplicates, publication presence)
 * 2. Clone subscription with all existing values
 * 3. Apply UI overrides
 * 4. Create a new Version record
 */
public with sharing class AEHC_SubscriptionPromoteController {

    /**
     * DTO used by UI to determine whether promotion is allowed
     * and to show appropriate error messages.
     */
    public class PromotionEligibility {
        @AuraEnabled public Boolean canPromote;
        @AuraEnabled public String message;
    }

    public class PromotionResponse {
    @AuraEnabled public Id versionId;
    @AuraEnabled public String environment;
    @AuraEnabled public String version;
    
@AuraEnabled public Boolean success;
    @AuraEnabled public String message;

	}

    
	public static Integer getEnvRank(String env) {     

            if (env == null) return 0;
            
            switch on env.toLowerCase() {
                when 'dev'  { return 1; }
                when 'qa'   { return 2; }
                when 'uat'  { return 3; }
                when 'production' { return 4; }
                when else   { return 0; }
            }
    }
    /**
     * Fetches Subscription record for UI display.
     * NOTE: Used only for UI, not cloning.
     */
    
    @AuraEnabled(cacheable=true)
    public static AEHC_Asset__C getSubscription(Id subscriptionId,String currentenv) {
        try{
             
        if (subscriptionId == null) return null;
          
        String RcrdTypId =
            Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Version')
                .getRecordTypeId();
            // check latest env
		List<AEHC_Asset__C> activeVersionSubs = new List<AEHC_Asset__C>();
            activeVersionSubs = [select id,AEHC_Environment__c from  AEHC_Asset__c where AEHC_Subscription_Request__c = : subscriptionId and
              AEHC_Is_Active__c = true and  RecordTypeId =: RcrdTypId ];       
		String env = '';
        String RecordIdAsset = '';
        for(AEHC_Asset__C loopvar : activeVersionSubs)
        {
            if(getEnvRank(env) < getEnvRank(loopvar.AEHC_Environment__c))
            {
                env = loopvar.AEHC_Environment__c;
                RecordIdAsset = loopvar.Id;
            }    
            
        }
		List<AEHC_Asset__C> versionSubs = new List<AEHC_Asset__C>();
            versionSubs = [
        SELECT
            Id,
            AEHC_Destination_Type__c,
            AEHC_Selected_Fields_JSON__c,
    		AEHC_Subscription_Request__r.AEHC_UAT_Approval__c,
            AEHC_Subscription_Request__r.AEHC_Transformation_Required__c,
            AEHC_Subscription_Request__r.AEHC_Transformation_ID__c,
            /* Database */
            AEHC_Database_Type__c,
            AEHC_JDBC_URL__c,
            AEHC_Host_Server__c,
            AEHC_Port__c,
            AEHC_Other_Properties__c,
            AEHC_Batch_Flag__c,
            AEHC_BatchSize__c,
            AEHC_Mute_Error_Flag__c,
            AEHC_On_Initialization__c,
            AEHC_On_Load__c,
            AEHC_On_Success__c,
            AEHC_On_Error__c,
    
            /* SFTP */
            AEHC_Remote_Directory_Path__c,
            AEHC_Filename__c,
            AEHC_Output_Format__c,
            AEHC_Include_Header__c,
            AEHC_Provide_Custom_Header__c,
            AEHC_Delimiter__c,
    
            /* Blob */
            AEHC_Storage_Account_Bucket__c,
            AEHC_Container_Folder_Path__c,
            AEHC_Blob_FileName__c,
    
            AEHC_Environment__c
        FROM AEHC_Asset__c
        WHERE AEHC_Subscription_Request__c = :subscriptionId
        AND AEHC_Environment__c = :currentenv
        AND AEHC_Is_Active__c = true
        AND RecordTypeId = :RcrdTypId    ];       
		
       
            if(versionSubs.size() >0)
            {
                return   versionSubs[0];
            }
            return null;
        }catch(Exception ex)
        {
            return null;
        }
    }

    /**
     * Determines whether a Subscription can be promoted.
     * Performs:
     * - Status validation
     * - Duplicate check
     * - Publication availability check
     * - Authorization check
     */
    @AuraEnabled(cacheable=true)
    public static PromotionEligibility checkEligibility(Id subscriptionId,String currentenv, String version) {

        PromotionEligibility res = new PromotionEligibility();
        res.canPromote = false;

        if (subscriptionId == null) {
            res.message = AEHC_Constant.ERR_INVALID_SUB;
            return res;
        }

        Subscription__c sub = [
            SELECT Id, Status__c, Subscriber__c,
                   AEHC_Environment__c,
                   AEHC_Publication_ID__c,AEHC_Consumming_Application__c,
                   AEHC_Publication_ID__r.AEHC_Publication__c, AEHC_UAT_Approval__c
            FROM Subscription__c
            WHERE Id = :subscriptionId
            LIMIT 1
        ];
        List<AEHC_Asset__C> activeVersionSubs = new List<AEHC_Asset__C>();
            activeVersionSubs = [select id,AEHC_Environment__c from  AEHC_Asset__c where AEHC_Subscription_Request__c = : subscriptionId and
              AEHC_Is_Active__c = true  ];       
		String env = '';
        String RecordIdAsset = '';
        for(AEHC_Asset__C loopvar : activeVersionSubs)
        {
            if(getEnvRank(env) < getEnvRank(loopvar.AEHC_Environment__c))
            {
                env = loopvar.AEHC_Environment__c;
                RecordIdAsset = loopvar.Id;
            }    
            
        }
        String nextEnv = getNextEnvironment(currentenv);//getNextEnvironment(sub.AEHC_Environment__c);

        
if(!sub.AEHC_UAT_Approval__c &&
   currentenv == 'QA')
{
    nextEnv = 'Production';
}

        List<AEHC_Asset__C> relatedSub = new List<AEHC_Asset__C>();
           relatedSub = [
            SELECT Id,Approval_Status__c
            FROM AEHC_Asset__C
            WHERE AEHC_Subscription_Request__c = : subscriptionId and 
            AEHC_Environment__c =: nextEnv
            AND AEHC_Schema_Version__c = :version
            LIMIT 1
        ];
        List<AEHC_Asset__C> currentSub = new List<AEHC_Asset__C>();
           currentSub = [
            SELECT Id,Approval_Status__c,AEHC_Environment__c,AEHC_Publication__c
            FROM AEHC_Asset__C
            WHERE AEHC_Subscription_Request__c = : subscriptionId and 
            AEHC_Environment__c =: currentenv//sub.AEHC_Environment__c
            AND AEHC_Schema_Version__c = :version
            LIMIT 1
        ];
        List<AEHC_Asset__c> publicationNextEnv = new List<AEHC_Asset__c>();
        string pubRecordTypeId =
            Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Version')
                .getRecordTypeId();
		 publicationNextEnv = [Select id,AEHC_Environment__c,Approval_Status__c from AEHC_Asset__C where AEHC_Publication__c =: sub.AEHC_Publication_ID__c
                              and AEHC_Environment__c =: nextEnv and AEHC_Is_Active__c = true and recordtypeID =: pubRecordTypeId];
            system.debug(publicationNextEnv);  
        	if(publicationNextEnv.size() == 0)
            {
                 res.message = 'Publication Record is not available for enironment : '+ nextEnv;
            return res;
        }

        if(relatedSub.size() >0 )
        {			
            
                 res.message = 'Record is already promoted to this org and is in status : '+relatedSub[0].Approval_Status__c;
            	return res;
        }
        if(currentSub.size() >0 ){
            if (currentSub[0].AEHC_Environment__c == AEHC_Constant.STATUS_PROD) {
                res.message = AEHC_Constant.ERR_NO_NEXT_ENV;
                return res;
            }
            if (currentSub[0].Approval_Status__c != 'Active') {
                res.message = AEHC_Constant.ERR_NOT_APPROVED;
                return res;
            }
            
            if (!isUserAuthorized(sub.AEHC_Consumming_Application__c, UserInfo.getUserId())) {
                res.message = AEHC_Constant.ERR_NOT_AUTHORIZED;
                return res;
            }
            
        }
        else {
             res.message = 'No Version Record ';
            	return res;
        }
        

        res.canPromote = true;
        res.message = null;
        return res;
    }

    /**
     * Creates a new Version of the Subscription for the next environment.
     * - Clones parent subscription
     * - Applies overrides from UI
     * - Sets environment and status
     */
    @AuraEnabled
    public static PromotionResponse promoteSubscription(
        Id parentSubscriptionId,
        Map<String, Object> overriddenFields,
        String currentenv,
        String version
    ) {
        String testString='';

        try{

        Subscription__c parentSub = [
            SELECT
        Id,
        Name,
        Status__c,
                AEHC_Environment__c,
                AEHC_Publication_ID__c,
                AEHC_Destination_Type__c,
                AEHC_Database_Type__c,
                AEHC_JDBC_Url__c,
                AEHC_On_Initalization__c,
                AEHC_On_Load__c,
                AEHC_On_Success__c,
                AEHC_On_Error__c,
                AEHC_Mute_Error_Flag__c,
                AEHC_Batch_Flag__c,
                Duration__c,
                AEHC_Other_Properties__c,
                AEHC_Publication_ID__r.AEHC_Publication__c,
                AEHC_Frequency__c,
                AEHC_Output_Format__c,
                AEHC_Filename__c,
                AEHC_Port__c,
                AEHC_Host_Server__c,
                AEHC_Application_Name__c,AEHC_Application_Name__r.Name,AEHC_Publication_ID__r.name,
                AEHC_Group_Account__c,AEHC_UAT_Approval__c

            FROM Subscription__c
            WHERE Id = :parentSubscriptionId
            LIMIT 1
        ];
		
        String RcrdTypId =
            Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get('AEHC_Version')
                .getRecordTypeId();
        List<AEHC_Asset__C> activeVersionSubs = new List<AEHC_Asset__C>();
            activeVersionSubs = [select id,AEHC_Environment__c from  AEHC_Asset__c where AEHC_Subscription_Request__c = : parentSubscriptionId and
              AEHC_Is_Active__c = true and  RecordTypeId =: RcrdTypId ];       
		String env = '';
        String RecordIdAsset = '';
        for(AEHC_Asset__C loopvar : activeVersionSubs)
        {
            if(getEnvRank(env) < getEnvRank(loopvar.AEHC_Environment__c))
            {
                env = loopvar.AEHC_Environment__c;
                RecordIdAsset = loopvar.Id;
            }    
            
        }
        List<AEHC_Asset__C> versionSubs = new List<AEHC_Asset__C>();
            versionSubs = [
    SELECT
        Id,
        Name,

        AEHC_Destination_Type__c,
        AEHC_VSchedule__c,
        AEHC_Frequency__c,
        AEHC_Time__c,
        AEHC_Weeks__c,
        AEHC_Weekdays__c,
        AEHC_Day_of_Month__c,
        AEHC_One_Time_Execution_Date__c,
        AEHC_One_Time_Execution_Time__c,
        AEHC_Transformation_Id__c,
        AEHC_Transformation_Required__c,
        /* Database */
        AEHC_Database_Type__c,
        AEHC_JDBC_URL__c,
        AEHC_Host_Server__c,
        AEHC_Port__c,
        AEHC_Other_Properties__c,
        AEHC_Batch_Flag__c,
        AEHC_BatchSize__c,
        AEHC_Mute_Error_Flag__c,
        AEHC_On_Initialization__c,
        AEHC_On_Load__c,
        AEHC_On_Success__c,
        AEHC_On_Error__c,

        /* SFTP */
        AEHC_Remote_Directory_Path__c,
        AEHC_Filename__c,
        AEHC_Output_Format__c,
        AEHC_Include_Header__c,
        AEHC_Provide_Custom_Header__c,
        AEHC_Delimiter__c,

        /* Blob */
        AEHC_Storage_Account_Bucket__c,
        AEHC_Container_Folder_Path__c,
        AEHC_Blob_FileName__c,

        AEHC_Schema_Version__c,
        AEHC_Application__c,
        AEHC_Is_Subscription__c,
        AEHC_Schedule_Summary__c,
        AEHC_Environment__c,
        AEHC_Subscription_Request__c,
        RecordTypeId,
        AEHC_CRON_Job_Expression__c,
        AEHC_Selected_Fields__c,
        AEHC_Selected_Fields_JSON__c,
        AEHC_Architect_Review_Done__c,
        AEHC_Publication__c
        FROM AEHC_Asset__c
        WHERE AEHC_Subscription_Request__c = :parentSubscriptionId
        AND AEHC_Environment__c = :currentenv
        AND AEHC_Schema_Version__c = :version
        AND RecordTypeId = :RcrdTypId    ];       
		
        String nextEnv = getNextEnvironment(currentenv);//(parentSub.AEHC_Environment__c);
		if( !parentSub.AEHC_UAT_Approval__c && currentenv == 'QA')
        {
			          nextEnv = 'Production';  
        }
        List<AEHC_Asset__c> existingVersion = [
    SELECT Id
    FROM AEHC_Asset__c
    WHERE AEHC_Subscription_Request__c = :parentSubscriptionId
    AND AEHC_Environment__c = :nextEnv
    AND AEHC_Schema_Version__c = :version
    LIMIT 1
];

if (!existingVersion.isEmpty()) {

    PromotionResponse res =
        new PromotionResponse();

    res.success = false;
    res.message =
        'Version ' + version +
        ' already exists in ' + nextEnv;

    return res;
}
        
        
        if (versionSubs.isEmpty()) {
    throw new AuraHandledException(
        'No source version found for environment ' + currentenv
    );
        }
                AEHC_Asset__c newVersion = versionSubs[0].clone(false, true, false, false);
                newVersion.Name = AEHC_PublicationSubRequestController.buildVersionName(
            parentSub.AEHC_Application_Name__r.Name,parentSub.AEHC_Publication_ID__r.name,
            nextEnv,
            newVersion.AEHC_Schema_Version__c
        );
                newVersion.AEHC_Environment__c = nextEnv;
        if(newVersion.AEHC_Environment__c == 'QA'|| ( newVersion.AEHC_Environment__c == 'Production'  ) )
        {
            newVersion.Approval_Status__c = 'DDH Admin Review';
        }
        
        if(newVersion.AEHC_Environment__c == 'UAT' || (newVersion.AEHC_Environment__c == 'Production'  && !parentSub.AEHC_UAT_Approval__c) )
        {
            newVersion.Approval_Status__c = 'Security Architect Review';
        }
            
            
               if (overriddenFields != null) {
                    
                    for (String f : overriddenFields.keySet()) {
                        
                        Object val = overriddenFields.get(f);
                        
                        System.debug('Field: ' + f + ' Value: ' + val);
                        
                        // TEXT / PICKLIST
                        if (
                f == 'AEHC_Destination_Type__c' ||
            
                /* Database */
                f == 'AEHC_Database_Type__c' ||
                f == 'AEHC_JDBC_URL__c' ||
                f == 'AEHC_Host_Server__c' ||
                f == 'AEHC_Other_Properties__c' ||
                f == 'AEHC_On_Initialization__c' ||
                f == 'AEHC_On_Load__c' ||
                f == 'AEHC_On_Success__c' ||
                f == 'AEHC_On_Error__c' ||
            
                /* SFTP */
                f == 'AEHC_Remote_Directory_Path__c' ||
                f == 'AEHC_Filename__c' ||
                f == 'AEHC_Output_Format__c' ||
                f == 'AEHC_Delimiter__c' ||
                f == 'AEHC_Selected_Fields_JSON__c' ||
                
            
                /* Blob */
                f == 'AEHC_Storage_Account_Bucket__c' ||
                f == 'AEHC_Container_Folder_Path__c' ||
                f == 'AEHC_Blob_FileName__c'
            )
            {
                if(f == 'AEHC_Selected_Fields_JSON__c' && String.isNotBlank(String.valueOf(val))){
                    
                    newVersion.put(f, String.valueOf(val));
                    
                } else if(f != 'AEHC_Selected_Fields_JSON__c'){
                    System.debug('data');
                            newVersion.put(f, String.valueOf(val));
                }
                    
            }
            
                                    
                                    //  CHECKBOX
                                    else if (
                f == 'AEHC_Mute_Error_Flag__c' ||
                f == 'AEHC_Batch_Flag__c' ||
            
                /* SFTP */
                f == 'AEHC_Include_Header__c' ||
                f == 'AEHC_Provide_Custom_Header__c'
            )
            {
                newVersion.put(f, (Boolean)val);
            }
                                    
                        //  NUMBER
                        else if (f == 'AEHC_BatchSize__c' ||  f == 'AEHC_Port__c' || f == 'AEHC_MaxFileSize__c') {
                                     
                                     
String strVal = String.valueOf(val);

    if (!String.isBlank(strVal)) {
        newVersion.put(
            f,
            Integer.valueOf(strVal)
        );
    }

                                 }                        
                           
                    }
                    String destinationType =
    String.valueOf(
        newVersion.AEHC_Destination_Type__c
    );
    if(newVersion.AEHC_Schema_Version__c != '1'){
            newVersion.AEHC_IntId__c=AEHC_PublicationSubRequestController.getIntId(parentSub.AEHC_Application_Name__c, parentSub.AEHC_Publication_ID__c, newVersion.AEHC_Environment__c,'1', true,parentSubscriptionId);
    }

        if(destinationType == 'BLOB')
        {
            // Clear Database
            newVersion.AEHC_Database_Type__c = null;
            newVersion.AEHC_JDBC_URL__c = null;
            newVersion.AEHC_Host_Server__c = null;
            newVersion.AEHC_Port__c = null;
            newVersion.AEHC_Other_Properties__c = null;
            newVersion.AEHC_Batch_Flag__c = false;
            newVersion.AEHC_BatchSize__c = null;
            newVersion.AEHC_Mute_Error_Flag__c = false;
            newVersion.AEHC_On_Initialization__c = null;
            newVersion.AEHC_On_Load__c = null;
            newVersion.AEHC_On_Success__c = null;
            newVersion.AEHC_On_Error__c = null;
        
            // Clear SFTP
            newVersion.AEHC_Remote_Directory_Path__c = null;
            newVersion.AEHC_Filename__c = null;
           // newVersion.AEHC_Include_Header__c = false;
           // newVersion.AEHC_Provide_Custom_Header__c = false;
            //newVersion.AEHC_Delimiter__c = null;
        }
        else if(destinationType == 'SFTP')
        {
            // Clear Blob
            newVersion.AEHC_Storage_Account_Bucket__c = null;
            newVersion.AEHC_Container_Folder_Path__c = null;
            newVersion.AEHC_Blob_FileName__c = null;
        
            // Clear Database
            newVersion.AEHC_Database_Type__c = null;
            newVersion.AEHC_JDBC_URL__c = null;
            newVersion.AEHC_Other_Properties__c = null;
            newVersion.AEHC_Batch_Flag__c = false;
            newVersion.AEHC_BatchSize__c = null;
        }
        else if(destinationType == 'Database')
        {
            // Clear Blob
            newVersion.AEHC_Storage_Account_Bucket__c = null;
            newVersion.AEHC_Container_Folder_Path__c = null;
            newVersion.AEHC_Blob_FileName__c = null;
        
            // Clear SFTP
            newVersion.AEHC_Remote_Directory_Path__c = null;
            newVersion.AEHC_Filename__c = null;
            newVersion.AEHC_Include_Header__c = false;
            //newVersion.AEHC_Provide_Custom_Header__c = false;
            newVersion.AEHC_Delimiter__c = null;
        }
                }

        insert newVersion;
        PromotionResponse res = new PromotionResponse();

res.versionId = newVersion.Id;
res.environment = nextEnv;
res.version = newVersion.AEHC_Schema_Version__c;

res.success = true;
res.message = 'Record promoted successfully';


return res;
        }catch(Exception ex)
        {
            system.debug(ex);
            
PromotionResponse res = new PromotionResponse();

    res.success = false;
    res.message = ex.getMessage()+ex.getStackTraceString()+'data'+testString+'testing';

    return res;

        
        }
    }

    /**
     * Checks whether current user is Developer or Business Owner
     * for the related Application.
     */
    public static Boolean isUserAuthorized(Id applicationId, Id userId) {

        if (UserInfo.getUserId() == userId) return true;
        if (applicationId == null) return false;

        
        return [
            SELECT COUNT()
            FROM AEHC_AssetMember__c
            WHERE 
             AEHC_User__c = :userId
              AND AEHC_Role__c IN ('Business Owner')
        ] > 0;
    }

    /**
     * Returns the next environment in the promotion flow.
     */
    public static String getNextEnvironment(String env) {
        switch on env {
            when 'Dev' { return AEHC_Constant.ENV_QA; }
            when 'QA'  { return AEHC_Constant.ENV_UAT; }
            when 'UAT' { return 'Production'; }
            when else { return null; }
        }
    }
}