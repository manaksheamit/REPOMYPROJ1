/**
 * @description       : 
 * @author            : Amit Manakshe
 * @group             : 
 * @last modified on  : 07-01-2026
 * @last modified by  : Amit Manakshe
**/
public with sharing class AEHC_EmbedPowerBIController {

    // Loading configuration from Custom Metadata `Config_Data__mdt`
    public static Config_Data__mdt mdRec;    

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllConfigs() {
        List<Map<String, String>> configList = new List<Map<String, String>>();
        List<Config_Data__mdt> configs = [SELECT DeveloperName, Label, Attribute_1__c, Attribute_2__c, Attribute_3__c, Attribute_4__c, Attribute_5__c, Attribute_6__c, Attribute_7__c, Attribute_9__c, Attribute_10__c FROM Config_Data__mdt];

        Set<String> userRoles = getCurrentUserAssetRoles();
        Boolean isSystemAdmin = isSystemAdminUser();

        for (Config_Data__mdt config : configs) {
            if (config.Attribute_10__c && (isConfigVisibleToUser(config, userRoles) || isSystemAdmin)) {
                Map<String, String> configMap = new Map<String, String>();
                configMap.put('label', config.Label != null ? config.Label : config.DeveloperName);
                configMap.put('name', config.DeveloperName);
                configList.add(configMap);
            }
        }
        return configList;
    }

    private static Boolean isSystemAdminUser() {
        Profile userProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        return userProfile != null && userProfile.Name == 'System Administrator';
    }

    private static Boolean isConfigVisibleToUser(Config_Data__mdt config,  Set<String> userRoles) {            
        Set<String> allowedRoles = splitCsv(config.Attribute_9__c);
        Boolean roleMatch = false;
        if (!allowedRoles.isEmpty() && !userRoles.isEmpty()) {
            for (String roleValue : userRoles) {
                if (allowedRoles.contains(roleValue)) {
                    roleMatch = true;                    
                    break;
                }
            }
        }
        if (allowedRoles.isEmpty()) {
            return false;
        }
        return roleMatch;        
    } 

    private static Set<String> getCurrentUserAssetRoles() {
        Set<String> roles = new Set<String>();
        List<AEHC_AssetMember__c> memberList= [SELECT Id, AEHC_Role__c  FROM AEHC_AssetMember__c WHERE AEHC_User__c  =: UserInfo.getUserId()];
        for (AEHC_AssetMember__c am : memberList) {                 
                if (!String.isBlank(am.AEHC_Role__c)) {
                    roles.add(normalizeText(am.AEHC_Role__c));
                }
        }              
        return roles;
    }

    private static Set<String> splitCsv(String input) {
        Set<String> values = new Set<String>();
        if (String.isBlank(input)) {
            return values;
        }
        for (String token : input.split(',')) {
            String normalized = normalizeText(token);
            if (!String.isBlank(normalized)) {
                values.add(normalized);
            }
        }
        return values;
    }

    private static String normalizeText(String input) {
        return input == null ? null : input.trim().toLowerCase();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getEmbedInfo(String metaddataName) {
        // Allow tests to set mdRec directly to avoid needing to insert custom metadata records.
        if (Test.isRunningTest()) {
            if (mdRec == null) {
                mdRec = Config_Data__mdt.getInstance(metaddataName);
            }
        } else {
            mdRec = Config_Data__mdt.getInstance(metaddataName);
        }
        
        if (mdRec == null) {
            throw new AuraHandledException('Config_Data__mdt record not found for metadata name: ' + metaddataName);
        }
        Map<String, String> result = new Map<String, String>();
        Set<String> userRoles = getCurrentUserAssetRoles();
        Boolean isSystemAdmin = isSystemAdminUser();
        if (!isSystemAdmin && !isConfigVisibleToUser(mdRec, userRoles)) {
            result.put('showReport', 'false');
            return result;            
        }
        
        String workspaceId = '';
        String reportId = '';
      

        if (mdRec.Attribute_2__c != null && String.isNotBlank(mdRec.Attribute_2__c)) {
            workspaceId = mdRec.Attribute_2__c;
        }
        if (mdRec.Attribute_3__c != null && String.isNotBlank(mdRec.Attribute_3__c)) {
            reportId = mdRec.Attribute_3__c;
        }

        String azureAccessToken = getAzureADAccessToken();
        String embedUrl = getReportMetadata(workspaceId, reportId, azureAccessToken);
        String embedToken = getPowerBIEmbedToken(workspaceId, reportId, azureAccessToken);

        result.put('embedUrl', embedUrl);
        result.put('embedToken', embedToken);
        result.put('reportId', reportId);
        result.put('showReport', 'true');
        return result;
    }

    public static String getAzureADAccessToken() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        // Using Named Credential for client credentials to avoid storing client id/secret in metadata
        String tenant = mdRec.Attribute_1__c;
        String namedCred = mdRec.Attribute_4__c;

        // Building endpoint using Named Credential callout prefix. 
        String endpoint = 'callout:' + namedCred + '/' + tenant + '/oauth2/v2.0/token';
        req.setEndpoint(endpoint);
        req.setMethod('POST');

        List<String> bodyString = mdRec.Attribute_6__c.split(',');
        String body = bodyString[0] + EncodingUtil.urlEncode(bodyString[1], bodyString[2]);
        req.setBody(body);    
             
        HttpResponse res = http.send(req);       
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(mdRec.Attribute_7__c + ': ' + res.getBody());
        }

        Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) tokenResponse.get('access_token');
    }

    private static String getReportMetadata(String workspaceId, String reportId, String azureAccessToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        String endpoint = mdRec.Attribute_5__c + workspaceId + '/reports/' + reportId;
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + azureAccessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(mdRec.Attribute_7__c + ': ' + res.getBody());
        }

        Map<String, Object> reportMeta = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) reportMeta.get('embedUrl');
    }

    private static String getPowerBIEmbedToken(String workspaceId, String reportId, String azureAccessToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        String endpoint = mdRec.Attribute_5__c + workspaceId + '/reports/' + reportId + '/GenerateToken';
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + azureAccessToken);

        Map<String, String> bodyMap = new Map<String, String>{'accessLevel' => 'View'};
        req.setBody(JSON.serialize(bodyMap));

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(mdRec.Attribute_7__c + ': ' + res.getBody());
        }

        Map<String, Object> tokenMeta = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) tokenMeta.get('token');
    }
}