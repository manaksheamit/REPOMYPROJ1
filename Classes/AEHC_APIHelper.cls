/**
 * @author Asif Ahmad
 * @date 22May2026
 * @description to behave as API Callout helper and log the error
*/
public class AEHC_APIHelper {
    
    static AEHC_HttpCallout calloutHelper;
    public static HttpResponse makeCalloutAndLogError(String method, String endpoint, String payload, Map<String, String> headers) {
        if(calloutHelper == null) calloutHelper = new AEHC_HttpCallout();
        
        HttpResponse response = calloutHelper.sendJSONRequest(method, endpoint, payload, headers);
        
        if(response.getStatusCode() == 200) return response;
        
        AEHC_Logger.logError(
            response.getBody(),
            'Apex',
            'AEHC_APIHelper.makeCallout',
            'Callout',
            null,
            'P2',
            'Integration',
            new Map<String, Object>{'endpoint' => endpoint, 'method' => payload, 'method' => payload, 'headers' => headers},
            AEHC_Utility.getCurrentEnvironment()
        );
        
        return response;
        
    }
    
    /**
     * @author Asif Ahmad
     * @date 23May2026
     * @description wrapper class for API result, with StatusCode, message and payload(data)
    */
    public class Result {
        public Integer statusCode;
        public String message;
        public Object data;
        
        public Result() {}
        
        public Result(Integer statusCode, String message, Object data) {
            this.statusCode = statusCode;
            this.message = message;
            this.data = data;
        }
    }
}