public class AEHC_Mule_FetchEnvironments1 {
    
    public static Map<String, String> getAllEnvironmentNames(){
        try{
        Map<String, String> envMap = new Map<String,String>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:MulesofApiCredentials1/accounts/api/organizations/9d1390e4-8f9f-406d-a404-a34085c57f2d/environments');
        request.setMethod('GET');
        request.setTimeout(120000);
        HttpResponse response = http.send(request);
        system.debug('resp:: '+response);
        if(response.getStatusCode()==200){
            Map<String, Object> root =
                (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> data =
                (List<Object>) root.get('data');
            for (Object item : data) {
                Map<String, Object> row = (Map<String, Object>) item;
                String id = (String) row.get('id');
                String name = (String) row.get('name');
                envMap.put(id,name);
            }
        }
        
        return envMap;
        }catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_Mule_FetchEnvironments1', 'Callout', null, 'P1', 'Integration', null, 'Dev');
            return null;
        }
    }
    @InvocableMethod(label='Get Dynamic Picklist Choices')
    public static List<List<AEHC_PicklistValue>> getAPIRelEnvironments(List<String> ApiName){
        
        try{
        List<AEHC_PicklistValue> options = new List<AEHC_PicklistValue>();
        List<List<AEHC_PicklistValue>> responseWrapper = new List<List<AEHC_PicklistValue>>();
        Map<String, String> envMap = new Map<String, String>();
        List<String> environmentIds = new List<String>();
        envMap = getAllEnvironmentNames();
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:MulesofApiCredentials1/exchange/api/v2/assets/9d1390e4-8f9f-406d-a404-a34085c57f2d/'+ApiName[0]+'/asset');
        request.setMethod('GET');
        request.setTimeout(120000);
        HttpResponse response = http.send(request);
        if(response.getStatusCode()==200){
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String assetId = (String) root.get('assetId');
            String versionGroup = (String) root.get('versionGroup');
            String resp = getAPIsEnv(assetId, versionGroup);
            List<Object> records = (List<Object>) JSON.deserializeUntyped(resp);
            for (Object obj : records) {
                Map<String, Object> row = (Map<String, Object>) obj;
                environmentIds.add((String) row.get('environmentId'));
            }
        }
        if(envMap!=null && environmentIds!=null){
            for(string envId : environmentIds){
                if(envMap.containsKey(envId)){
                    options.add(new AEHC_PicklistValue(envMap.get(envId),envMap.get(envId)));
                }
            }
        }
            if('Yes'.equalsIgnoreCase(System.Label.AEHC_Environments_List_Required)) {
                options = new List<AEHC_PicklistValue>();
                options.add(new AEHC_PicklistValue('DEV', 'DEV'));
                options.add(new AEHC_PicklistValue('QA', 'QA'));
                options.add(new AEHC_PicklistValue('UAT', 'UAT'));
                options.add(new AEHC_PicklistValue('PROD', 'PROD'));
            }
            responseWrapper.add(options);
        return responseWrapper;
        }catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_Mule_FetchEnvironments1', 'Callout', null, 'P1', 'Integration', null, 'Dev');
            return null;
        }
    }
    /*public static List<List<String>> getAPIRelEnvironments(List<String> ApiName){
Map<String, String> envMap = new Map<String, String>();
List<List<String>> EnvironmentsList = new List<List<String>>();
List<String> Environments = new List<String>();
List<String> environmentIds = new List<String>();
envMap = getAllEnvironmentNames();
Http http = new Http();
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:MulesofApiCredentials1/exchange/api/v2/assets/9d1390e4-8f9f-406d-a404-a34085c57f2d/'+ApiName[0]+'/asset');
request.setMethod('GET');
request.setTimeout(120000);
HttpResponse response = http.send(request);
if(response.getStatusCode()==200){
Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
String assetId = (String) root.get('assetId');
String versionGroup = (String) root.get('versionGroup');
String resp = getAPIsEnv(assetId, versionGroup);
List<Object> records = (List<Object>) JSON.deserializeUntyped(resp);
for (Object obj : records) {
Map<String, Object> row = (Map<String, Object>) obj;
environmentIds.add((String) row.get('environmentId'));
}
}
if(envMap!=null && environmentIds!=null){
for(string envId : environmentIds){
if(envMap.containsKey(envId)){
Environments.add(envMap.get(envId));
}
}
}

system.debug('env: '+Environments);
EnvironmentsList.add(Environments);
return EnvironmentsList;
}*/
    public static string getAPIsEnv(String assetID, String versionGroup){
        string resp;
        try{
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:MulesofApiCredentials1/exchange/api/v2/assets/9d1390e4-8f9f-406d-a404-a34085c57f2d/'+assetID+'/versionGroups/'+versionGroup+'/instances');
        request.setMethod('GET');
        request.setTimeout(120000);
        HttpResponse response = http.send(request);
        if(response.getStatusCode()==200){    
            resp = response.getBody();
        }
        
        return resp;
        }catch(Exception ex)
        {
           AEHC_Logger.logException(ex, 'Apex', 'AEHC_Mule_FetchEnvironments1', 'Callout', null, 'P1', 'Integration', null, 'Dev');
            return null;
        }
    }  

    

}