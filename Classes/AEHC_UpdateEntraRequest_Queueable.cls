public class AEHC_UpdateEntraRequest_Queueable implements Queueable, Database.AllowsCallouts {

    private List<Id> recordIds;

    public AEHC_UpdateEntraRequest_Queueable(List<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {

        Http http = new Http();

        List<Subscription__c> records = [
            SELECT Id,
                   AEHC_SubscriberEmail__c,
                   AEHC_Environment_Name__c,
                   AEHC_Consuming_Application_Name__c,
                   AEHC_Purpose_of_Use__c,
                   AEHC_Intra_Request__c,
            		AEHC_Permission_Name__c,
                    AEHC_Consuming_App_Registration_Name__c,
                    AEHC_Consuming_App_Registration_ID__c
            FROM Subscription__c
            WHERE Id IN :recordIds
        ];

        List<Subscription__c> updates = new List<Subscription__c>();

        Map<String, String> accessTokenByEnv = new Map<String, String>();

        for (Subscription__c rec : records) {

            try {

                String envKey = getEnvKey(System.Label.AEHC_Environment_Name);

                AEHC_Entra_Config__mdt config = [
                    SELECT OAuth_Endpoint__c,
                           ClientID__c,
                           ClientSecret__c,
                           GrantType__c,
                           Endpoint__c,
                           Environment__c,
                           Environment_API__c,
                           Environment_Map__c,
                           HoldingAppID__c,
                           ApplicationID__c,
                           ApplicationNamePrefix__c
                    FROM AEHC_Entra_Config__mdt
                    WHERE MasterLabel = :envKey
                    LIMIT 1
                ];

              /*  String accessToken;

                if (accessTokenByEnv.containsKey(envKey)) {
                    accessToken = accessTokenByEnv.get(envKey);
                } else {
                    accessToken = getAccessToken(config);
                    accessTokenByEnv.put(envKey, accessToken);
                }
                system.debug('accessToken:'+accessToken);*/
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:AEHC_Update_App_registration');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                //req.setHeader('Authorization', 'Bearer ' + accessToken);
                req.setTimeout(120000);
                Map<String, Object> payload = new Map<String, Object>();
                payload.put('requesterName', rec.AEHC_SubscriberEmail__c);
                payload.put('memberFirm', 'Global');
                payload.put('environment', config.Environment_Map__c);
                payload.put('applicationName', rec.AEHC_Consuming_App_Registration_Name__c);
                payload.put('applicationId', rec.AEHC_Consuming_App_Registration_Id__c);
                //payload.put('ApplicationPermission', 'Cross Application Permissions');
                //payload.put('ApplicationType', 'Add Settings');
                payload.put('updateTarget', 'Cross Application Permissions');
               payload.put('updateOperation', 'Add Settings');

                payload.put('holdingAppId', config.HoldingAppID__c);
                payload.put('delegatedPermission', 'user.read');
                payload.put('applicationPermissions', rec.AEHC_Permission_Name__c);

                // Uncomment if moving to dynamic value later
                // payload.put('RequesterName', rec.AEHC_SubscriberEmail__c);
				System.debug('entra update debug-'+JSON.serialize(payload));
                req.setBody(JSON.serialize(payload));

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {

                    Map<String, Object> resp =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    if (resp.containsKey('result')) {

                        Map<String, Object> resultMap =
                            (Map<String, Object>) resp.get('result');

                        String requestNumber =
                            resultMap.containsKey('RequestNumber')
                            ? String.valueOf(resultMap.get('RequestNumber'))
                            : null;

                        String requestStatus =
                            resultMap.containsKey('Message')
                            ? String.valueOf(resultMap.get('Message'))
                            : null;
                        system.debug('requestNumber:'+requestNumber);
                        if (String.isNotBlank(requestNumber)) {
                            rec.AEHC_Intra_Request__c = requestNumber;
                            rec.AEHC_App_Registration_RITM_Status__c = requestStatus;
                            updates.add(rec);
                        }
                    }
                } else {

                    throw new CalloutException(
                        'API Call Failed. Status Code: ' +
                        res.getStatusCode() +
                        ', Response: ' +
                        res.getBody()
                    );
                }

            } catch (Exception ex) {

                AEHC_Logger.logException(
                    ex,
                    'Apex',
                    'AEHC_UpdateEntraRequest_Queueable',
                    'Callout',
                    rec.Id,
                    'P1',
                    'Integration',
                    null,
                    System.Label.AEHC_Environment_Name
                );
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /**
     * OAuth Token Generation
     */
   /* private static String getAccessToken(AEHC_Entra_Config__mdt config) {

        Http http = new Http();

        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setEndpoint(config.OAuth_Endpoint__c);
        tokenReq.setMethod('POST');
        tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        tokenReq.setTimeout(120000);

        String requestBody =
            'grant_type=' + EncodingUtil.urlEncode(config.GrantType__c, 'UTF-8') +
            '&client_id=' + EncodingUtil.urlEncode(config.ClientID__c, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(config.ClientSecret__c, 'UTF-8');

        tokenReq.setBody(requestBody);

        HttpResponse tokenRes = http.send(tokenReq);

        if (tokenRes.getStatusCode() == 200) {

            Map<String, Object> tokenResponse =
                (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());

            if (tokenResponse.containsKey('access_token')) {
                return String.valueOf(tokenResponse.get('access_token'));
            }

            throw new CalloutException(
                'Access token not found in OAuth response.'
            );
        }

        throw new CalloutException(
            'OAuth Token Generation Failed. Status Code: ' +
            tokenRes.getStatusCode() +
            ', Response: ' +
            tokenRes.getBody()
        );
    }*/

    private static String getEnvKey(String env) {

        if (String.isBlank(env)) {
            return 'DevUpdate';
        }

        String normalized = env.toLowerCase();

        if (normalized.contains('dev')) return 'DevUpdate';
        if (normalized.contains('qa')) return 'QAUpdate';
        if (normalized.contains('uat')) return 'UatUpdate';
        if (normalized.contains('prod')) return 'ProdUpdate';

        return 'DevUpdate';
    }
}