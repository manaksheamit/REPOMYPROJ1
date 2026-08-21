/**
 * @author Asif Ahmad
 * @date 15Apr2026
 * @description To Invoke MuleSoft endpoint API and get API collections
*/
public class AEHC_Mule_GetAPIService {
    
    String NAMED_CREDENTIAL;
    AEHC_HttpCallout calloutHelper;
    
    // payload fields
    Anypoint_Connection__mdt config;
    String ORG_ID;
    Integer api_Offset;
    Integer api_Limit;
    List<Object> assets;
    
    public AEHC_Mule_GetAPIService() {
        calloutHelper = new AEHC_HttpCallout();
        NAMED_CREDENTIAL = 'MulesofApiCredentials1';
        
        config = Anypoint_Connection__mdt.getInstance('Anypoint_Get_All_APIs');
        api_Offset = 0;
        api_Limit = 250;
        assets = new List<Object>();
    }
    
    public static List<Object> getAPIs() {
        AEHC_Mule_GetAPIService apiService = new AEHC_Mule_GetAPIService();
        
        apiService.execute();
        
        return apiService.assets;
    }
    
    void execute() {
        HttpResponse response = callAPI();
        
        process(response);
    }
       
    HttpResponse callAPI() {
        
        String endpoint = 'callout:' + NAMED_CREDENTIAL + '/' + config.OrganizationURL__c;
        
        String payload = '{"query": "{assets(organizationIds: [\\"' + config.OrganizationId__c + '\\"] , types: [], latestVersionsOnly : true, offset: ' + api_Offset + ', limit: ' + api_Limit + ') {type contactName}}"}';
        HttpResponse apiResponse = calloutHelper.sendAsPost(endpoint, payload, null);
        
        return apiResponse;
    }
    
    void process(HttpResponse apiResponse) {
        Integer statusCode = apiResponse.getStatusCode();
        if(statusCode != 200) return;
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(apiResponse.getBody());
        if(!responseBody.containsKey('data')) return;
        
        Map<String, Object> responseBody_data = (Map<String, Object>)responseBody.get('data');    
        if(!responseBody_data.containsKey('assets')) return;
        
        List<Object> responseBody_dataAssets = (List<Object>)responseBody_data.get('assets');
        
        Integer assetCounts = 0;
        for(Object assetItem : responseBody_dataAssets) {
            
            assets.add(assetItem);
            assetCounts++;
        } 
        
        if(assetCounts >= api_Limit) {
            api_Offset += api_Limit;
            execute();
        }
    }

}