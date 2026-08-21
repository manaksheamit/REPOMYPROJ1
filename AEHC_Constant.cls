/*Class to handle Constant Value For Self Service Portal
 * 
 */
global class AEHC_Constant {

   
    public static final String PROFILE_EXTERNAL_IDENTITY = 'API Experience Hub Member User';
    public static final String DEFAULT_TIMEZONE = 'America/Los_Angeles';
    public static final String DEFAULT_LOCALE = 'en_US';
    public static final String DEFAULT_ENCODING = 'UTF-8';
    public static final String USERNAME_SUFFIX = '.aeh_dev_feb';
    public static final String PORTAL_ACCOUNT_NAME = 'API Experience Hub Account - 0DB9V000000SivlWAC';
    // SAML Attribute URIs
    public static final String CLAIM_EMAIL = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';
    public static final String CLAIM_SURNAME = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname';
    public static final String CLAIM_GIVENNAME = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname';
    public static final String CLAIM_GROUPS = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/groups';
    
    public static final String SAML_NS = 'urn:oasis:names:tc:SAML:2.0:assertion';


    global static Map<string,list<string>> GROUP_PERMISSION = 
        new Map<string,list<string>>{
        'Sales_User' => new List<String>{'Sales_User'}
    };
    public static String BATCH_APEX= 'Batch Apex';
    public static String QUEUEABLE_APEX= 'Queueable Apex';
    public static String FUTURE_APEX= 'Future Apex';
    public static String SCEHEDULED_APEX= 'Scheduled Apex';
    public static String FLOW= 'Flow';
    public static String PROD= 'Prod';
    public static String SANDBOX= 'Sandbox';
    public static String STATUS_NEW = 'New';
    public Static String CATEGORY_UNKNOWN = 'Unknown';
    public Static String CUSTOM_ERROR = 'CustomError';
    public Static String FLOW_ERROR ='FlowError';
    
    public static String APPROVED = 'Approved';
    public static String REJECTED = 'Rejected';
    public static String SUBMITTED = 'Submitted';
    public static String RECALLED = 'Recalled';
    public static String ACTIVE = 'Active';
    public static String INTERNAL_EVALUATION = 'Internal Evaluation';
    public static String ROLE_SBO = 'Subscriber Business Owner';
    
    // Callout Constants
    public static String CONTENT_TYPE = 'Content-Type';
    public static String APPLICATION_JSON = 'application/json';
    public static String ASSET_OWNER = 'Asset Owner';
    
    public static String RECORDTYPENAME_ASSET_APPLICATION = 'AEHC_Application';
    public static String RECORDTYPENAME_ASSET_VERSION = 'AEHC_Version';
    public static String RECORDTYPENAME_SUBSCRIPTION_API = 'API_Asset';
    public static String RECORDTYPENAME_SUBSCRIPTION_DATA = 'Data_Publication';
    
    public static String CM_API_MuleFlex_Auth = 'AEHC_MuleFlex_Auth';
    public static String CM_API_SNOW_AppSearchByName = 'AEHC_SNOW_AppSearchByName';
    public static String CM_API_SNOW_AppSearchByAPMNumber = 'AEHC_SNOW_AppSearchByAPMNumber';
    public static String CM_API_SNOW_AppSearchData = 'AEHC_ServiceNowData';
    public static String CM_API_SNOW_Base = 'AEHC_SNOW_Base';
    
    // API related details
    public static String HEADER_AUTHORIZATION = 'Authorization';
    public static String GET = 'GET';
    public static String BEARER = 'Bearer';
    public static String APPLICATION_WWW_FORM_URL_ENCODED = 'application/x-www-form-urlencoded';
     
    //Subscription Promotion
    
	public static  String STATUS_APPROVED = 'Approved';
    public static  String STATUS_PROD = 'PROD';
    public static  String STATUS_PENDING_QA ='Pending QA Promotion';

    public static  String STATUS_PENDING_UAT =
       Label.AEHC_Pending_UAT_Promotion_Approval;
    public static  String STATUS_PENDING_PROD =
        Label.AEHC_Pending_Production_Promotion_Approval;
    public static  String STATUS_SUBMITTED =
        'Submitted';
    public static  String ENV_DEV = 'Dev';
    public static  String ENV_QA = 'QA';
    public static  String ENV_UAT = 'UAT';
    public static  String ENV_PROD = 'PROD'; 
    public static  String ERR_INVALID_SUB =
        Label.AEHC_Invalid_subscription;
    public static  String ERR_NOT_APPROVED =  Label.AEHC_Subscription_is_not_approved; 
    public static  String ERR_NOT_AUTHORIZED =
        Label.AEHC_not_authorized_to_promote_this_subscription;
    public static  String ERR_ALREADY_PROMOTED =
        Label.AEHC_already_promoted_to_this_org;
    public static  String ERR_NO_NEXT_ENV =
        Label.AEHC_Prod_no_next_org_to_promote;
    public static final String ERR_NO_PUBLICATION =
       Label.AEHC_Publication_Record_is_not_available;
    public static  String ROLE_DEVELOPER =
        'Developer';
    public static  String ROLE_BUSINESS_OWNER =
        'Business Owner';
    public static  String ROLE_IT_OWNER = 'IT Owner';
    public static  String ROLE_SECURITY_ARCHITECT = 'Security Architect';
    public static  String ROLE_DDH_ADMIN = 'DDH Admin';
    
    // Labels
    public static String LBL_NO_APP_FOUND = Label.AEHC_Application_NotFound;
    public static String LBL_APP_CREATE_SUCCESS = Label.AEHC_Application_CreateSuccess;

    // description limit
    public static final Integer DESCRIPTION_LIMIT = 255;

    
}