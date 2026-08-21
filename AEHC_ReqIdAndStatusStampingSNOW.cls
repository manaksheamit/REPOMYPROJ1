public class AEHC_ReqIdAndStatusStampingSNOW {
    
    private static String accessToken;
    private static Long expiryTime;

    // Get config
    private static AEHC_ServiceNow_Config__mdt getConfig() {
        return AEHC_ServiceNow_Config__mdt.getInstance('API_Details_RITM_Status');
    }
    
     @AuraEnabled
    // STEP 1: GET TOKEN
    public static String getAccessToken() {
        try{
            if (accessToken != null && System.currentTimeMillis() < expiryTime) {
                return accessToken;
            }
            AEHC_ServiceNow_Config__mdt config = getConfig();
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
    
    // Method 2: Call API using Access Token
    @AuraEnabled
    public static String getRequestDetails(String recordId) {
    try {

        System.debug('===== START getRequestDetails =====');
        System.debug('Input recordId: ' + recordId);

        

       /* System.debug('Access Token Retrieved: ' +
            (String.isNotBlank(accessToken) ? 'YES' : 'NO'));*/

        AEHC_ServiceNow_Config__mdt config = getConfig();
		Boolean tokenRequired = config.Is_Token_Required__c;
        System.debug('Config Retrieved: ' + config);

        List<Subscription__c> subList = [
            SELECT Id,
                   AEHC_SNow_Request__c,
                   AEHC_SNow_Status__c,
                   RecordType.DeveloperName
            FROM Subscription__c
            WHERE Id = :recordId
            AND RecordType.DeveloperName = :Label.AEHC_SubReq_API_Asset_RecType
        ];
        System.debug('Label.AEHC_SubReq_API_Asset_RecType ' + Label.AEHC_SubReq_API_Asset_RecType);
        System.debug('Subscription Records Found: ' + subList.size());

        if (subList.isEmpty()) {
            System.debug('No Subscription record found matching criteria.');
            return null;
        }

        System.debug('Subscription Record: '
            + JSON.serializePretty(subList[0]));

        System.debug('SNOW Request Number: '
            + subList[0].AEHC_SNow_Request__c);

       /* if (String.isBlank(accessToken)) {
            System.debug('Access Token is blank.');
            return null;
        }*/

        String endpoint =
            config.Create_Request_Endpoint__c +
            subList[0].AEHC_SNow_Request__c +
            config.Endpoint_Fields__c;

        System.debug('Generated Endpoint: ' + endpoint);

        HttpRequest req = new HttpRequest();

        req.setEndpoint('callout:AEH_ServiceNow_Status_NC'+
            subList[0].AEHC_SNow_Request__c +
            config.Endpoint_Fields__c);
        req.setMethod('GET');
        if(tokenRequired){
            String accessToken = getAccessToken();
            req.setHeader('Authorization', 'Bearer ' + accessToken);
        }else{
            req.setHeader('client_id', config.client_id__c);
            req.setHeader('client_secret', config.client_secret__c);
        }
        
        System.debug('HttpRequest Prepared');

        Http http = new Http();

        System.debug('Sending Request to ServiceNow...');

        HttpResponse res = http.send(req);

        System.debug('HTTP Status Code: ' + res.getStatusCode());
        System.debug('HTTP Status: ' + res.getStatus());
        System.debug('Response Body: ' + res.getBody());

        String responseBody = res.getBody();

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        System.debug('Parsed Response Map: '
            + JSON.serializePretty(responseMap));

        if (!responseMap.containsKey('result')) {
            System.debug('Response does not contain "result" node.');
            return responseBody;
        }

        List<Object> resultList =
            (List<Object>) responseMap.get('result');

        System.debug('Result List Size: '
            + (resultList == null ? 0 : resultList.size()));

        if (resultList == null || resultList.isEmpty()) {
            System.debug('Result list is empty.');
            return responseBody;
        }

        Map<String, Object> firstRecord =
            (Map<String, Object>) resultList[0];

        System.debug('First ServiceNow Record: '
            + JSON.serializePretty(firstRecord));

        String stage = (String) firstRecord.get('stage');

        System.debug('Stage Retrieved: ' + stage);

        subList[0].AEHC_SNow_Status__c = stage;

        System.debug('Updating Subscription Status to: ' + stage);

        update subList;

        System.debug('Subscription Updated Successfully');

        System.debug('===== END getRequestDetails SUCCESS =====');

        return responseBody;

    } catch (Exception ex) {

        System.debug('===== EXCEPTION IN getRequestDetails =====');
        System.debug('Exception Type: ' + ex.getTypeName());
        System.debug('Exception Message: ' + ex.getMessage());
        System.debug('Stack Trace: ' + ex.getStackTraceString());

        AEHC_Logger.logException(
            ex,
            'Apex',
            'AEHC_ServiceNowIntegration',
            'Callout',
            null,
            'P1',
            'Integration',
            null,
            System.Label.AEHC_Environment_Name
        );

        return null;
    }
}
}