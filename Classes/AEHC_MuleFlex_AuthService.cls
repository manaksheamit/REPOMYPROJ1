/**
 * @author Asif Ahmad
 * @date 21May2026
 * @description to behave as Auth Provide for MuleFlex Auth API
*/
public class AEHC_MuleFlex_AuthService {
    
    static AEHC_HttpCallout calloutHelper;
    public static String getAuthToken() {
        
        // get API Config from Metadata
        AEHC_APIConfig__mdt apiConfig = AEHC_Utility.getAPIConfig(AEHC_Constant.CM_API_MuleFlex_Auth);
        if(apiConfig == null) return null;
       
        // key-values are already encoded and stored in External credentials
        String externalCredential = apiConfig.AEHC_ExternalCredential__c;
        
        String body = 'grant_type={!$Credential.' + externalCredential + '.grant_type}';
        body += '&client_id={!$Credential.' + externalCredential + '.client_id}';
        body += '&client_secret={!$Credential.' + externalCredential + '.client_secret}';
        body += '&username={!$Credential.' + externalCredential + '.username}';
        body += '&password={!$Credential.' + externalCredential + '.password}';
        
        Map<String, String> headers = new Map<String, String>();
        headers.put(AEHC_Constant.CONTENT_TYPE, AEHC_Constant.APPLICATION_WWW_FORM_URL_ENCODED);
        
        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(apiConfig.AEHC_Method__c, apiConfig.AEHC_Endpoint__c, body, headers);
        
        String resBodyStr = response.getBody();
        if(response.getStatusCode() == 200) {
            Map<String, Object> resBody = (Map<String, Object>)JSON.deserializeUntyped(resBodyStr);
            
            return AEHC_Utility.getStringFromMap(resBody, 'access_token', null);
        }
        
        return null;
        
    }
}