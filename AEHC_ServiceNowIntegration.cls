public class AEHC_ServiceNowIntegration {
    
    private static String accessToken;
    private static Long expiryTime;
    
    // Get config
    private static AEHC_ServiceNow_Config__mdt getConfig(string env) {
        return AEHC_ServiceNow_Config__mdt.getInstance(env);
    }
    
    // STEP 1: GET TOKEN
    public static String getAccessToken(string env) {
        try{
            if (accessToken != null && System.currentTimeMillis() < expiryTime) {
                return accessToken;
            }
            AEHC_ServiceNow_Config__mdt config = getConfig('API_Details');
            String endpoint = config.Token_Endpoint__c;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(
                'grant_type=password' +
                '&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8') +
                '&username=' + EncodingUtil.urlEncode(config.Username__c, 'UTF-8') +
                '&password=' + EncodingUtil.urlEncode(config.Password__c, 'UTF-8')
            );
            req.setTimeout(120000);
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                accessToken = (String) result.get('access_token');
                Integer expiresIn = (Integer) result.get('expires_in');
                expiryTime = System.currentTimeMillis() + (expiresIn * 1000);
                return accessToken;
                
            } else {
                throw new CalloutException(
                    'Token Error: ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }
        }
        catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_ServiceNowIntegration', 'Callout', null, 'P1', 'Integration', null, System.Label.AEHC_Environment_Name);
            return null;
        }
    }
    
    //STEP 2: CALL API
    @InvocableMethod(label='Create RITM ServiceNow Request')
    public static List<String> createRequest(List<String> SubReqID) {
        try{
            List<String> requestNumber = new List<String>();
            if(SubReqID!=null){
                Subscription__c subreq = [select id, AEHC_Purpose_of_Use__c, AEHC_IP_Address_of_the_Application__c, AEHC_APM_Number__c,CreatedBy.Email, AEHC_Director_SysID__c,AEHC_Environment_Name__c from Subscription__c where id=:SubReqID[0]];
                if(subreq!=null){
                    //AEHC_ServiceNow_Config__mdt config = getConfig(getEnvKey(subreq.AEHC_Environment_Name__c));
                    AEHC_ServiceNow_Config__mdt config = getConfig('API_Details');
                    Boolean tokenRequired = config.Is_Token_Required__c;
                    String endpoint = config.Create_Request_Endpoint__c;
                    HttpRequest req = new HttpRequest();
                  /*  if(tokenRequired){
                        String token = getAccessToken('API_Details');
                        req.setHeader('Authorization', 'Bearer ' + token);
                    	system.debug('token: '+token);
                    }*/
                    req.setEndpoint('callout:AEHC_ServiceNow_Firewall_Creation');
                    system.debug('endpoint req :'+endpoint);
                    req.setMethod('POST');
                    req.setTimeout(120000);
                    req.setHeader('Content-Type', 'application/json');
                    if(!tokenRequired){
                        req.setHeader('client_id', config.client_id__c);
                        req.setHeader('client_secret', config.client_secret__c);
                    }
                    Date d = Date.today();
                    String todayStr = d.year() + '-' +
                        String.valueOf(d.month()).leftPad(2, '0') + '-' +
                        String.valueOf(d.day()).leftPad(2, '0');
                    
                    // JSON BODY
                    Map<String, Object> bodyMap = new Map<String, Object>{
                        'sysparm_quantity' => 1,
                            
                            'variables' => new Map<String, Object>{
                                'u_approver' => subreq.AEHC_Director_SysID__c,
                                    'sys_bus_owner' => subreq.CreatedBy.Email,
                                    'con_duration' => 'Temporary',
                                    'data_plan' => '500MB',
                                    'does_this_involve_cisco_acl_in_the_ddc' => 'No',
                                    'temp_connection' => DateTime.now().format('yyyy-MM-dd'),
                                    'req_type' => 'Add',
                                    'does_this_request_include_a_deny_rule' => 'No',
                                    'is_change_to_be_made_within_the_cloud' => 'No',
                                    'spread_sheet' => 'No',
                                    'port_info' => '8082',
                                    

                                    'hidden_ui_page_ports' => new Map<String, Object>{
                                        'Protocol' => 'TCP',
                                        'Ports' => '8082',
                                        'destination_IP_Address' => subreq.AEHC_IP_Address_of_the_Application__c,
                                        'source_IP_Address' => subreq.AEHC_IP_Address_of_the_Application__c
                                    },
                                    
                                    'security_exception_id' => '123',
                                    'bus_justification' => subreq.AEHC_Purpose_of_Use__c
                                    }
                        
                    };
                        //system.debug(AEHC_ServiceNowIntegration.createRequest(new List<String>{'a029V00000cnrwXQAQ'}));    
                        req.setBody(JSON.serializePretty(bodyMap));
                    system.debug('req:'+JSON.serializePretty(bodyMap));
                    system.debug('bodyMap:'+bodyMap);
                    Http http = new Http();
                    HttpResponse res = http.send(req);
                    System.debug('Status: ' + res.getStatusCode());
                    System.debug('Response: ' + res.getBody());
                    //PARSE request_number
                    Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> resultMap = (Map<String, Object>) resp.get('result');
                    requestNumber.add((String) resultMap.get('request_number'));
                }
            }  
            return requestNumber;
        }
        catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_ServiceNowIntegration', 'Callout', null, 'P1', 'Integration', null, System.Label.AEHC_Environment_Name);
            
            return null;
        }
    }
   /* private static String getEnvKey(String env) {

        if (String.isBlank(env)) return 'Create_RITM_Dev';

        String normalized = env.toLowerCase();

        if (normalized.contains('dev')) return 'Create_RITM_Dev';
        if (normalized.contains('qa')) return 'Create_RITM_Qa';
        if (normalized.contains('uat')) return 'Create_RITM_Uat';
        if (normalized.contains('prod')) return 'Create_RITM_Prod';

        return 'Create_RITM_Dev';
    }*/
}