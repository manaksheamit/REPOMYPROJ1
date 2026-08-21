/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : AEHC_SubscriptionDetailPageController
 * Author          : Umang Rohitbhai Fofariya
 * Created Date    : Jun 17, 2026
 * Last Modified By: Umang Rohitbhai Fofariya
 * Last Modified On: Jun 22, 2026
 * Description     :
 *
 * AEHC Subscription Detail Page Controller (LWC Backend)
 * ------------------------------------------------------
 * This Apex controller provides backend services for rendering Subscription details
 * and version-specific configurations in Salesforce Experience Cloud.
 *
 * The controller is designed to support a version-controlled Subscription model,
 * where each Subscription maintains multiple environment-specific versions (Dev, QA, UAT, Prod),
 * with full visibility into version metadata, approval state, and configuration details.
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 CORE FUNCTIONALITIES
 * ─────────────────────────────────────────────────────────────
 *
 * 1) Subscription Detail Retrieval
 *    - getSubscriptionDetailPageData(subscriptionId)
 *    - Fetches Subscription metadata along with:
 *        • Application and Publication details
 *        • Purpose of use
 *        • Subscription owner and current user
 *        • User edit permissions (Owner or Business Owner of Application)
 *
 *    - Retrieves ALL Subscription versions (AEHC_Asset__c) and:
 *        • Groups them by Environment (Dev, QA, UAT, Prod, etc.)
 *        • Returns structured environment → version mapping
 *        • Includes version number, active flag, and approval status
 *
 * 2) Version Details Retrieval
 *    - getSubscriptionVersionDetails(subscriptionId, environment, versionNumber)
 *    - Fetches complete configuration for a specific Subscription version:
 *
 *         Basic Info:
 *           - Application, Publication, Purpose of Use
 *           - Version number and environment
 *
 *         Schema Configuration:
 *           - Selected fields (JSON parsed)
 *           - Transformation flags
 *
 *         Schedule Configuration:
 *           - Frequency, cron expression, execution time
 *           - Weekly, multi-weekly, monthly, and one-time settings
 *
 *         Destination Configuration:
 *           - SFTP details (host, path, format, delimiter, etc.)
 *           - Database connection configuration
 *           - Blob storage configuration
 *
 *         Integration Metadata:
 *           - Transformation Id
 *           - Integration Id
 *           - Approval Status
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 VERSIONING MODEL SUPPORT
 * ─────────────────────────────────────────────────────────────
 *
 *  - Supports multi-version Subscription architecture aligned with Publication versioning.
 *  - Each version is uniquely identified by:
 *        • Environment
 *        • Version Number (AEHC_Schema_Version__c)
 *
 *  - Enables:
 *        Version tracking across environments
 *        Active version identification
 *        Approval status monitoring
 *        Full configuration visibility per version
 *
 *  - Data is structured in a UI-friendly format:
 *        Map<Environment, List<VersionDTO>>
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 SECURITY & ACCESS CONTROL
 * ─────────────────────────────────────────────────────────────
 *
 *  - Determines edit access using:
 *        • Subscription Owner (Subscriber__c)
 *        • Business Owner role via AEHC_AssetMember__c
 *
 *  - Fallback mechanism:
 *        • If Application is not directly linked,
 *          retrieves Primary Application from User → Contact mapping
 *
 *  - Ensures only authorized users can modify Subscription data.
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 ERROR HANDLING & LOGGING
 * ─────────────────────────────────────────────────────────────
 *
 *  - Uses centralized logging via AEHC_Logger.logException
 *  - Logs include:
 *        • Method name
 *        • UserId
 *        • SubscriptionId / Version context
 *        • Environment context
 *
 *  - Handles:
 *        • QueryException → "Subscription / Version not found"
 *        • Generic Exception → "Unable to load details"
 *
 *  - Ensures consistent logging pattern across all methods
 *    using structured context maps.
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 DESIGN CONSIDERATIONS
 * ─────────────────────────────────────────────────────────────
 *
 *  - Uses @AuraEnabled(cacheable=true) for read methods
 *    (optimized for LWC performance)
 *
 *  - Separates:
 *        • Summary view (Subscription + all versions)
 *        • Detailed view (specific version)
 *
 *  - JSON fields are safely parsed using deserializeUntyped
 *
 *  - Environment detection handled dynamically via org domain
 *
 *  - Data model aligned with enterprise versioning approach:
 *        • Clean separation of environments
 *        • Immutable version records
 *        • UI-friendly DTO structures
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 DEPENDENCIES
 * ─────────────────────────────────────────────────────────────
 *
 *  - AEHC_Asset__c → Subscription Version records
 *  - Subscription__c → Base Subscription object
 *  - AEHC_AssetMember__c → User roles (Business Owner)
 *  - AEHC_Logger → Centralized logging framework
 *
 * ─────────────────────────────────────────────────────────────
 * 🔹 NOTES
 * ─────────────────────────────────────────────────────────────
 *
 *  - Designed specifically for LWC Subscription Detail Page
 *  - Supports future enhancements such as:
 *        • Version lineage (previous version tracking)
 *        • Version comparison (diff view)
 *        • Approval workflows
 *        • Version activation controls
 *
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Change History  :
 *  Date          │   Author                      │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 17, 2026  │ Umang Rohitbhai Fofariya     │ Initial version
 *  Jun 22, 2026  │ Umang Rohitbhai Fofariya     │ Added versioning support, DTO structuring,
 *                                               centralized logging, and detailed response handling
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class AEHC_SubscriptionDetailPageController {

public class SubscriptionDetailResponse {
    @AuraEnabled public String subscriptionName;
    @AuraEnabled public String applicationName;
    @AuraEnabled public String publicationName;
    @AuraEnabled public String applicationId;
    @AuraEnabled public String publicationId;
    @AuraEnabled public String publicationRecordId;
    @AuraEnabled public String purposeOfUse;

    @AuraEnabled public Id currentUserId;
    @AuraEnabled public Id subscriptionOwnerId;
    @AuraEnabled public Boolean isEditableUser;

    @AuraEnabled public List<String> environments;
    @AuraEnabled public Map<String, List<VersionDTO>> environmentMap;
}

public class VersionDTO {
    @AuraEnabled public String versionNumber;
    @AuraEnabled public Boolean isActive;
    
   @AuraEnabled public String approvalStatus;
}

private static final String COMPONENT_TYPE = 'Apex';
private static final String COMPONENT_NAME = 'AEHC_SubscriptionDetailPageController';
private static final String OPERATION_QUERY = 'Query';
private static final String SEVERITY_P2 = 'P2';
private static final String CATEGORY = 'SubscriptionDetail';



@AuraEnabled(cacheable=true)
public static SubscriptionDetailResponse getSubscriptionDetailPageData(Id subscriptionId) {

    Map<String, Object> context = new Map<String, Object>{
    'method' => 'getSubscriptionDetailPageData',
    'userId' => UserInfo.getUserId(),
    'subscriptionId' => subscriptionId
};

String orgEnv = getCurrentEnvironment();

    /*
    ✅ STEP 0: Validate Input
    */
    if (subscriptionId == null) {
        throw new AuraHandledException('Subscription Id is required');
    }

    try {

        /*
        ✅ STEP 1: Fetch Subscription WITH RecordType
        */
        Subscription__c sub = [
            SELECT Name,
                   RecordType.Name,
                   AEHC_Application_Name__r.Name,
                   AEHC_Application_Name__r.AEHC_Application_Id__c,
                   AEHC_Publication_ID__r.Name,
                   AEHC_Publication_ID__r.AEHC_Publication_Id__c,
                   AEHC_Publication_ID__c,
                   AEHC_Purpose_of_Use__c,
                   AEHC_Consumming_Application__c,
                   Subscriber__c  
            FROM Subscription__c
            WHERE Id = :subscriptionId
            LIMIT 1
        ];

        /*
        ✅ STEP 2: RecordType Validation
        */
        if (sub.RecordType == null || sub.RecordType.Name != 'Data Publication') {
            throw new AuraHandledException('This page is only available for Data Products subscriptions');
        }

        /*
        ✅ STEP 3: Fetch ALL versions
        */
        List<AEHC_Asset__c> versions = [
            SELECT AEHC_Environment__c,
                   AEHC_Schema_Version__c,
                   AEHC_Is_Active__c,   
                   Approval_Status__c,
                   AEHC_Subscription_Request__r.Subscriber__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :subscriptionId
            AND AEHC_Is_Subscription__c = true
            ORDER BY AEHC_Environment__c, AEHC_Schema_Version__c DESC
        ];

        /*
        ✅ STEP 4: Build Environment Map
        */
        Map<String, List<VersionDTO>> envMap = new Map<String, List<VersionDTO>>();

        for (AEHC_Asset__c v : versions) {

            String env = v.AEHC_Environment__c;

            if (String.isBlank(env)) continue;

            if (!envMap.containsKey(env)) {
                envMap.put(env, new List<VersionDTO>());
            }

            VersionDTO dto = new VersionDTO();
            dto.versionNumber = v.AEHC_Schema_Version__c;
            dto.isActive = v.AEHC_Is_Active__c;
            dto.approvalStatus = v.Approval_Status__c;
            envMap.get(env).add(dto);
        }

        Id currentUserId = UserInfo.getUserId();
        // ✅ STEP 5A: Get consuming application
        Id consumingAppId = sub.AEHC_Consumming_Application__c;
        // ✅ STEP 5B: If NULL → fallback to Primary App from Contact
        if (consumingAppId == null) {            
            User u = [SELECT ContactId  FROM User   WHERE Id = :UserInfo.getUserId()];
            if (u.ContactId != null) {
                Contact c = [SELECT AEHC_App__c FROM Contact WHERE Id = :u.ContactId LIMIT 1];
                consumingAppId = c.AEHC_App__c;
            }
        }

        Boolean isBO = false;
        if (consumingAppId != null) {
            List<AEHC_AssetMember__c> members = [ SELECT Id FROM AEHC_AssetMember__c WHERE AEHC_Asset__c = :consumingAppId AND AEHC_User__c = :currentUserId AND AEHC_Role__c = 'Business Owner' LIMIT 1];
            isBO = !members.isEmpty();
        }            
        Boolean isOwner = (sub.Subscriber__c == currentUserId);
        /*
        ✅ STEP 6: Build Response
        */
        SubscriptionDetailResponse res = new SubscriptionDetailResponse();

        res.subscriptionName = sub.Name;
        res.applicationName = sub.AEHC_Application_Name__r.Name;
        res.applicationId = sub.AEHC_Application_Name__r.AEHC_Application_Id__c;
        res.publicationName = sub.AEHC_Publication_ID__r.Name;
        res.publicationId = sub.AEHC_Publication_ID__r.AEHC_Publication_Id__c;
        res.publicationRecordId = sub.AEHC_Publication_ID__c;
        res.purposeOfUse = sub.AEHC_Purpose_of_Use__c;
        res.currentUserId = UserInfo.getUserId(); 
        res.subscriptionOwnerId = sub.Subscriber__c;
        List<String> envList = new List<String>(envMap.keySet());
        envList.sort();
        res.environments = envList;
        res.environmentMap = envMap;
        res.isEditableUser = (isOwner || isBO);
        return res;

    } catch (QueryException qe) {

         AEHC_Logger.logException(
        qe,
        COMPONENT_TYPE,
        COMPONENT_NAME,
        OPERATION_QUERY,
        subscriptionId,
        SEVERITY_P2,
        CATEGORY,
        context,
        orgEnv
    );


        throw new AuraHandledException('Subscription not found');

    } catch (Exception ex) {

 AEHC_Logger.logException(
        ex,
        COMPONENT_TYPE,
        COMPONENT_NAME,
        OPERATION_QUERY,
        subscriptionId,
        SEVERITY_P2,
        CATEGORY,
        context,
        orgEnv
    );

        throw new AuraHandledException('Unable to load subscription details');
    }
}
@AuraEnabled(cacheable=true)
public static Map<String, Object> getSubscriptionVersionDetails(
    Id subscriptionId,
    String environment,
    String versionNumber
) {

    Map<String, Object> context = new Map<String, Object>{
    'method' => 'getSubscriptionVersionDetails',
    'subscriptionId' => subscriptionId,
    'environment' => environment,
    'versionNumber' => versionNumber,
    'userId' => UserInfo.getUserId()
};

String orgEnv = getCurrentEnvironment();

    if (subscriptionId == null || String.isBlank(environment) || versionNumber == null) {
        throw new AuraHandledException('Invalid input');
    }

   try{
AEHC_Asset__c v = [
    SELECT 
        Name,
        Approval_Status__c,
        AEHC_Transformation_Id__c,
        AEHC_IntId__c,
        AEHC_Environment__c,
        AEHC_Schema_Version__c,
        AEHC_Purpose_of_Use__c,
        AEHC_Application__c,
        AEHC_Application__r.Name,
        AEHC_Application__r.AEHC_Application_Id__c,
        AEHC_Publication__r.Name,
        AEHC_Publication__r.AEHC_Publication_Id__c,
        AEHC_Subscription_Request__r.AEHC_Consumming_Application__r.Name,
        AEHC_Transformation_Required__c,
        AEHC_Subscription_Request__r.AEHC_Transformation_ID__c,
        AEHC_Selected_Fields_JSON__c,

        /* ✅ SCHEDULE */
        AEHC_VSchedule__c,
        AEHC_Frequency__c,
        AEHC_Time__c,
        AEHC_Weeks__c,
        AEHC_Weekdays__c,
        AEHC_Day_of_Month__c,
        AEHC_One_Time_Execution_Date__c,
        AEHC_One_Time_Execution_Time__c,
        AEHC_Schedule_Summary__c,
        AEHC_CRON_Job_Expression__c,

        /* ✅ DESTINATION COMMON */
        AEHC_Destination_Type__c,

        /* ✅ SFTP */
        AEHC_Host_Server__c,
        AEHC_Port__c,
        AEHC_Remote_Directory_Path__c,
        AEHC_Filename__c,
        AEHC_Output_Format__c,
        AEHC_Include_Header__c,
        AEHC_Provide_Custom_Header__c,
        AEHC_Delimiter__c,

        /* ✅ DATABASE */
        AEHC_Database_Type__c,
        AEHC_JDBC_URL__c,
        AEHC_Other_Properties__c,
        AEHC_Batch_Flag__c,
        AEHC_BatchSize__c,
        AEHC_On_Initialization__c,
        AEHC_On_Load__c,
        AEHC_On_Success__c,
        AEHC_On_Error__c,
        AEHC_Mute_Error_Flag__c,

        /* ✅ BLOB */
        AEHC_Storage_Account_Bucket__c,
        AEHC_Container_Folder_Path__c,
        AEHC_Blob_FileName__c

    FROM AEHC_Asset__c
    WHERE AEHC_Subscription_Request__c = :subscriptionId
    AND AEHC_Environment__c = :environment
    AND AEHC_Schema_Version__c = :versionNumber
    LIMIT 1
];

    /*
    ✅ Build response
    */
    Map<String, Object> res = new Map<String, Object>();
    
res.put('applicationName', v.AEHC_Application__r?.Name);
res.put('publicationName', v.AEHC_Publication__r?.Name);
res.put('applicationId', v.AEHC_Application__r?.AEHC_Application_Id__c);
res.put('publicationId', v.AEHC_Publication__r?.AEHC_Publication_Id__c);
res.put('consumingApplicationName', v.AEHC_Subscription_Request__r?.AEHC_Consumming_Application__r?.Name);
res.put('purposeOfUse', v.AEHC_Purpose_of_Use__c);
res.put('environment', v.AEHC_Environment__c);
res.put('versionNumber', v.AEHC_Schema_Version__c);
res.put('applicationRecordId', v.AEHC_Application__c);
res.put('transformationRequired', v.AEHC_Transformation_Required__c);
res.put('transformationId', v.AEHC_Transformation_ID__c);
res.put('selectedFieldsJson',
    String.isNotBlank(v.AEHC_Selected_Fields_JSON__c)
    ? (List<Object>) JSON.deserializeUntyped(v.AEHC_Selected_Fields_JSON__c)
    : new List<Object>()
);
Map<String, Object> schedule = new Map<String, Object>();

schedule.put('schedulerMode', v.AEHC_VSchedule__c);
schedule.put('frequency', v.AEHC_Frequency__c);
schedule.put(
    'scheduleTime',
    v.AEHC_Time__c == null
        ? null
        : String.valueOf(v.AEHC_Time__c)
);
schedule.put('weekdays', 
    v.AEHC_Weekdays__c != null ? v.AEHC_Weekdays__c.split(';') : null);
schedule.put('multiWeekWeeks',
    v.AEHC_Weeks__c != null ? v.AEHC_Weeks__c.split(';') : null);
    
schedule.put(
    'multiWeekDays',
    v.AEHC_Weekdays__c != null
        ? v.AEHC_Weekdays__c.split(';')
        : null
);
schedule.put('monthlyDay', v.AEHC_Day_of_Month__c);
schedule.put('oneTimeDate', v.AEHC_One_Time_Execution_Date__c);
schedule.put('oneTimeTime', v.AEHC_One_Time_Execution_Time__c);
schedule.put('scheduleSummary', v.AEHC_Schedule_Summary__c);
schedule.put('cronExpression', v.AEHC_CRON_Job_Expression__c);

res.put('versionName', v.Name);
res.put('approvalStatus', v.Approval_Status__c);
res.put('integrationId', v.AEHC_IntId__c);


res.put('schedule', schedule);

Map<String, Object> dest = new Map<String, Object>();

dest.put('destinationType', v.AEHC_Destination_Type__c);

/* ✅ SFTP */
if (v.AEHC_Destination_Type__c == 'SFTP') {
    dest.put('sftpHostName', v.AEHC_Host_Server__c);
    dest.put('sftpPort', v.AEHC_Port__c);
    dest.put('sftpRemotePath', v.AEHC_Remote_Directory_Path__c);
    dest.put('sftpFileName', v.AEHC_Filename__c);
    dest.put('sftpOutputFormat', v.AEHC_Output_Format__c);
    dest.put('includeHeader', v.AEHC_Include_Header__c);
    dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
    dest.put('delimiter', v.AEHC_Delimiter__c);
}

/* ✅ DATABASE */
if (v.AEHC_Destination_Type__c == 'Database') {
    dest.put('databaseType', v.AEHC_Database_Type__c);
    dest.put('databaseHost', v.AEHC_Host_Server__c);
    dest.put('databasePort', v.AEHC_Port__c);
    dest.put('jdbcUrl', v.AEHC_JDBC_URL__c);
    dest.put('otherProperties', v.AEHC_Other_Properties__c);
    dest.put('batchFlag', v.AEHC_Batch_Flag__c);
    dest.put('batchSize', v.AEHC_BatchSize__c);

    dest.put('spOnInit', v.AEHC_On_Initialization__c);
    dest.put('spOnLoad', v.AEHC_On_Load__c);
    dest.put('spOnSuccess', v.AEHC_On_Success__c);
    dest.put('spOnError', v.AEHC_On_Error__c);
    dest.put('muteErrorFlag', v.AEHC_Mute_Error_Flag__c);
    dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
}

/* ✅ BLOB */
if (v.AEHC_Destination_Type__c == 'BLOB') {
    dest.put('storageAccount', v.AEHC_Storage_Account_Bucket__c);
    dest.put('containerPath', v.AEHC_Container_Folder_Path__c);
    dest.put('outputFormat', v.AEHC_Output_Format__c);
    dest.put('blobFileName', v.AEHC_Blob_FileName__c);
    dest.put('includeHeader', v.AEHC_Include_Header__c);
    dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
    dest.put('delimiter', v.AEHC_Delimiter__c);
}

res.put('destination', dest);

    return res;
   } 
catch (QueryException qe) {

    AEHC_Logger.logException(
        qe,
        COMPONENT_TYPE,
        COMPONENT_NAME,
        OPERATION_QUERY,
        subscriptionId,
        SEVERITY_P2,
        CATEGORY,
        context,
        orgEnv
    );

    throw new AuraHandledException('Version not found');

} catch (Exception ex) {

    AEHC_Logger.logException(
        ex,
        COMPONENT_TYPE,
        COMPONENT_NAME,
        OPERATION_QUERY,
        subscriptionId,
        SEVERITY_P2,
        CATEGORY,
        context,
        orgEnv
    );

    throw new AuraHandledException('Unable to load version details');
}

}
private static String getCurrentEnvironment() {
    String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();

    if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
        if (domain.contains('dev')) return 'Dev';
        if (domain.contains('qa')) return 'QA';
        if (domain.contains('uat')) return 'UAT';
        return 'Sandbox';
    }
    return 'Prod';
}


}