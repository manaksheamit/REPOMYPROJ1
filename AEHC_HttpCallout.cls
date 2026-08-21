/**
 * @author Asif Ahmad
 * @date 15Apr2026
 * @description to behave as HTTP Callout helper
*/
public with sharing class AEHC_HttpCallout implements Database.AllowsCallouts {
    
    public String APPLICATION_WWW_FORM_URL_ENCODED = AEHC_Constant.APPLICATION_WWW_FORM_URL_ENCODED;
    public String ACCEPT = 'Accept';
    public String METHOD_GET = AEHC_Constant.GET, METHOD_POST = 'POST';
    public Integer DEFAULT_TIME_OUT = 120000;
    public String HEADER_AUTHORIZATION = AEHC_Constant.HEADER_AUTHORIZATION;
    public String BEARER = AEHC_Constant.BEARER;
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description to make HTTP API calls to given method, endpoints, payload, header and timeout details  
     * @return to return result in HttpResponse
	*/
    public HttpResponse send(String reqMethod, String reqURL, String reqBody, Map<String, String> reqHeaderMap, Integer timeOut) {
        HttpResponse response = new HttpResponse();
        try {
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setMethod(reqMethod);
            req.setEndpoint(reqURL);
            
            req.setTimeout(timeOut == null ? DEFAULT_TIME_OUT : timeOut);
            if(reqBody != null) req.setBody(reqBody);
            
            // Request Header
            if(reqHeaderMap != null) for(String headerKey : reqHeaderMap.keySet()) req.setHeader(headerKey, reqHeaderMap.get(headerKey));
            
            response = h.send(req);
        } catch(Exception e) {
            Map<String, Object> exceptionMap = new Map<String, Object>();
            exceptionMap.put('cause', e.getCause());
            exceptionMap.put('lineNumber', e.getLineNumber());
            exceptionMap.put('type', e.getTypeName());
            exceptionMap.put('message', e.getMessage());
            
            response.setStatusCode(500);
            response.setStatus('ApexException');
            response.setBody(JSON.serialize(exceptionMap));
        }
        return response;
    }
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description public helper method, to make HTTP API calls to given method, endpoints, payload, header and timeout details, default Header JSON
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendJSONRequest(String reqMethod, String reqURL, String reqBody, Map<String, String> reqHeaderMap, Integer timeOut) {
        if(reqHeaderMap == null) reqHeaderMap = new Map<String, String>();
        
        if(!reqHeaderMap.containsKey(AEHC_Constant.CONTENT_TYPE)) reqHeaderMap.put(AEHC_Constant.CONTENT_TYPE, AEHC_Constant.APPLICATION_JSON);
        if(!reqHeaderMap.containsKey(ACCEPT)) reqHeaderMap.put(ACCEPT, AEHC_Constant.APPLICATION_JSON);
        return send(reqMethod, reqURL, reqBody, reqHeaderMap, timeOut);
    }
    
    /**
     * @author Asif Ahmad
     * @date 23May2026
     * @description public helper method, to make HTTP API calls to given method, endpoints, payload, header, default Header JSON, default time null
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendJSONRequest(String reqMethod, String reqURL, String reqBody, Map<String, String> reqHeaderMap) {
        return sendJSONRequest(reqMethod, reqURL, reqBody, reqHeaderMap, null);
    }
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description to make HTTP API calls to given method:GET, endpoints, header and  default Header JSON
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendAsGET(String reqURL, Map<String, String> reqHeaderMap) {
        return sendJSONRequest(METHOD_GET, reqURL, null, reqHeaderMap, null);
    }
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description to make HTTP API calls to given method:GET, endpoints, header, timeout and  default Header JSON
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendAsGET(String reqURL, Map<String, String> reqHeaderMap, Integer timeOut) {
        return sendJSONRequest(METHOD_GET, reqURL, null, reqHeaderMap, timeOut);
    }
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description to make HTTP API calls to given method:POST, endpoints, payload, header and  default Header JSON
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendAsPOST(String reqURL, String reqBody, Map<String, String> reqHeaderMap) {
        return sendJSONRequest(METHOD_POST, reqURL, reqBody, reqHeaderMap, null);
    }
    
    /**
     * @author Asif Ahmad
     * @date 15Apr2026
     * @description to make HTTP API calls to given method:POST, endpoints, payload, header, timeout and  default Header JSON
     * @return to return result in HttpResponse
	*/
    public HttpResponse sendAsPOST(String reqURL, String reqBody, Map<String, String> reqHeaderMap, Integer timeOut) {
        return sendJSONRequest(METHOD_POST, reqURL, reqBody, reqHeaderMap, timeOut);
    }
}