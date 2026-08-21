/**
 * @author Asif Ahmad
 * @date 21May2026
 * @description to behave as Searching for an application using Service Now API
*/
public class AEHC_SNOW_ApplicationSearchService {
    
    AEHC_HttpCallout calloutHelper;
    String authToken;
    String searchKeyword;
    List<Object> apps;
    AEHC_APIHelper.Result result;
    
    public AEHC_SNOW_ApplicationSearchService(String searchKeyword) {
        calloutHelper = new AEHC_HttpCallout();
        this.searchKeyword = searchKeyword;
        result = new AEHC_APIHelper.Result();
    }
    
    public static AEHC_APIHelper.Result searchApplication(String searchKeyword) {
        AEHC_SNOW_ApplicationSearchService appSearchService = new AEHC_SNOW_ApplicationSearchService(searchKeyword);
        appSearchService.execute();
        
        return appSearchService.result;
    }
    
    void execute() {
        if(searchKeyword != null) searchKeyword = searchKeyword.trim();
        if(String.isEmpty(searchKeyword)) return;
        
        /*authToken = AEHC_MuleFlex_AuthService.getAuthToken();
        if(String.isEmpty(authToken)) {
            result.statusCode = 401;
            return;
        }*/
        
        if(searchKeyword.toLowerCase().startsWith('apm')) invokeSearchAPIByAPMNumber();
        else invokeSearchAPIByName();
        
        if(apps.isEmpty()) {
            result.statusCode = 404;
            return;
        }
        result.data = apps;
        result.statusCode = 200;
    }
    
    
    /**
     * @author Asif Ahmad
     * @date 21May2026
     * @description to behave as Searching for an application using Service Now API, search by name
    */
    void invokeSearchAPIByName() {
        
        // get API Config from Metadata
        AEHC_APIConfig__mdt apiConfig = AEHC_Utility.getAPIConfig(AEHC_Constant.CM_API_SNOW_AppSearchByName);
        if(apiConfig == null) return;
        
        Map<String, String> headers = new Map<String, String>();
        //headers.put(calloutHelper.HEADER_AUTHORIZATION, calloutHelper.BEARER + ' ' + authToken);
        
        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(apiConfig.AEHC_Method__c, apiConfig.AEHC_Endpoint__c + EncodingUtil.urlEncode(searchKeyword, 'UTF-8'), null, headers);        

        String resBodyStr = response.getBody();
        if(response.getStatusCode() == 200) {
            
            Map<String, Object> resBody = (Map<String, Object>)JSON.deserializeUntyped(resBodyStr);
            
            Object result = AEHC_Utility.getValueAsObjectFromMap(resBody, 'result', null);
            
            if(result != null) {
                apps = (List<Object>)result;
            }
        }
    }
    
    /**
     * @author Asif Ahmad
     * @date 21May2026
     * @description to behave as Searching for an application using Service Now API, search by APM Number
    */
    void invokeSearchAPIByAPMNumber() {

        // get API Config from Metadata
        AEHC_APIConfig__mdt apiConfig = AEHC_Utility.getAPIConfig(AEHC_Constant.CM_API_SNOW_AppSearchByAPMNumber);
        if(apiConfig == null) return;
        
        Map<String, String> headers = new Map<String, String>();
        //headers.put(calloutHelper.HEADER_AUTHORIZATION, calloutHelper.BEARER + ' ' + authToken);
        
        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(apiConfig.AEHC_Method__c, apiConfig.AEHC_Endpoint__c + EncodingUtil.urlEncode(searchKeyword, 'UTF-8'), null, headers);        

        String resBodyStr = response.getBody();
        if(response.getStatusCode() == 200) {
            
            Map<String, Object> resBody = (Map<String, Object>)JSON.deserializeUntyped(resBodyStr);
            
            Object result = AEHC_Utility.getValueAsObjectFromMap(resBody, 'result', null);
            
            if(result != null) {
                apps = (List<Object>)result;
            }
        }
    }
    
    public static String authToken;
    public static AEHC_APIHelper.Result invokeServiceNowAPI(String method, String subURL) {        
        AEHC_APIHelper.Result result = new AEHC_APIHelper.Result();
        
        // make Auth Call
        /*if(String.isEmpty(authToken)) {
            authToken = AEHC_MuleFlex_AuthService.getAuthToken();
            if(String.isEmpty(authToken)) {
                result.statusCode = 401;
                return result;
            }
        }*/
        
        // get API Config from Metadata
        AEHC_APIConfig__mdt apiConfig = AEHC_Utility.getAPIConfig(AEHC_Constant.CM_API_SNOW_AppSearchData);
        if(apiConfig == null) {
            result.statusCode = 400;
            result.message = 'NO_METADATA_CONFIG';
            return result;
        }  
        
        Map<String, String> headers = new Map<String, String>();
        //headers.put(AEHC_Constant.HEADER_AUTHORIZATION, AEHC_Constant.BEARER + ' ' + authToken);

        HttpResponse response = AEHC_APIHelper.makeCalloutAndLogError(method, apiConfig.AEHC_Endpoint__c + subURL, null, headers);
        
        String resBodyStr = response.getBody();
        if(response.getStatusCode() == 200) {
            result.statusCode = 200;
            result.data = resBodyStr;
        } else {
            result.statusCode = response.getStatusCode();
            result.data = resBodyStr;
        }
        
        return result;
    }
    
   

}