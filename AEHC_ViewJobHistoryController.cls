/*
    @Author : Parvej Alam
    @Apex Class : AEHC_ViewJobHistoryController
    @Test Class : AEHC_ViewJobHistoryControllerTest
    @Description : In this class we are calling final status and Audit API to show ViewRunJobHistory
*/
public without sharing class AEHC_ViewJobHistoryController {
    
    public class RunWrapper {
        @AuraEnabled public String runId;
        @AuraEnabled public String previousRunId;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public String status;
        @AuraEnabled public String intId;
        
    }
    
    public class AuditWrapper {
        @AuraEnabled public String stage;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String recordCount;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }
    
    
    public class JobRunsResponse {
        @AuraEnabled public String intId;
        @AuraEnabled public List<RunWrapper> runs;
    }
    
    @AuraEnabled
    public static JobRunsResponse  getJobRuns(String recordId, String env) {
        
        try{
            List<RunWrapper> runList = new List<RunWrapper>();
             Datetime today = System.today();
             Datetime yesterday = today.addDays(-1);
             AEHC_Asset__c sub = [SELECT AEHC_IntId__c
  	                from AEHC_Asset__c where (AEHC_Subscription_Request__c =:recordId OR AEHC_Publication__c = :recordId) 
                                  AND AEHC_Is_Active__c = true AND AEHC_Environment__c=:env LIMIT 1];                   
            
            if(sub == null){
                throw new AuraHandledException('Error fetching job runs');
            }
            string intId =   sub.AEHC_IntId__c; 
            
            if (String.isBlank(intId)) {
                throw new AuraHandledException('Subscription Id is missing.');
            }
            
			JobHistoryEndpointConfig__mdt config =AEHC_EnvironmentBasedUrlConfigs.getConfig(env, 'ViewJobHistory');

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Endpoint_URL__c + intId);
            req.setMethod('GET');
            
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                string response = res.getBody();
                Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(response);
                List<Object> runs = (List<Object>) parsedData.get('runs');
                
                for (Object obj : runs) {
                    Map<String, Object> item = (Map<String, Object>) obj;
                    
                    RunWrapper rw = new RunWrapper();
                    rw.runId = (String) item.get('runId');
                    rw.previousRunId = item.get('previousRunId') != null ? String.valueOf(item.get('previousRunId')) : '-';
                    
                    rw.startTime = item.get('runStartTime') != null
                        ? String.valueOf(item.get('runStartTime'))
                        : String.valueOf(yesterday);
                    
                    rw.endTime = item.get('runEndTime') != null
                        ? String.valueOf(item.get('runEndTime'))
                        : String.valueOf(today);
                    
                    rw.recordCount = (Integer) item.get('recordCount');
                    rw.status = (String) item.get('status');
                    rw.intId = intId;
                    
                    runList.add(rw);
                }
                
                JobRunsResponse responseWrapper = new JobRunsResponse();
                responseWrapper.intId = intId;
                responseWrapper.runs = runList;
                
                return responseWrapper;
                
            } else {
                throw new AuraHandledException('Error fetching job runs');
            }
            
        }
        catch (Exception ex) {
            safeLogException(ex, 'getJobRuns', recordId);
            throw ex;
        }
        
    }
    
    @AuraEnabled
    public static List<AuditWrapper> getAuditDetails(String intId, String runId, String env) {
        try{
            JobHistoryEndpointConfig__mdt config =AEHC_EnvironmentBasedUrlConfigs.getConfig(env, 'ViewAuditHistory');
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Endpoint_URL__c + intId + '&runId=' + runId);
			req.setMethod('GET');
            
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                string response = res.getBody();
                Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(response);
                
                List<Object> auditList = (List<Object>) parsedData.get('audit');
                String recordCount = String.valueOf(parsedData.get('recordCount'));
                
                List<AuditWrapper> auditResult = new List<AuditWrapper>();
                
                for (Object obj : auditList) {
                    Map<String, Object> item = (Map<String, Object>) obj;
                    
                    AuditWrapper aw = new AuditWrapper();
                    aw.stage = (String) item.get('stage');
                    aw.startTime = String.valueOf(item.get('timestamp'));
                    aw.endTime = String.valueOf(item.get('timestamp'));
                    aw.recordCount = recordCount;
                    aw.status = (String) item.get('status');
                    aw.message = (String) item.get('message');
                    
                    auditResult.add(aw);
                }
                
                return auditResult;
                
            } else {
                throw new AuraHandledException('Error fetching audit details');
            }
        }
        catch (Exception ex) {
            safeLogException(ex, 'getAuditDetails', intId);
            throw new AuraHandledException('Error fetching audit details'+ex);
            
        }
    }

    @AuraEnabled
    public static Boolean requestSnapshot(string intId, String runId, String env){
         try{
            String getRunId = runId != null ? runId : '';
            JobHistoryEndpointConfig__mdt config =AEHC_EnvironmentBasedUrlConfigs.getConfig(env, 'Snapshot');
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            // Endpoint
            req.setEndpoint(config.Endpoint_URL__c + '/snapshot');
			req.setHeader('Content-Type', 'application/json');
			req.setMethod('POST');

            // Body (JSON)
            String requestBody = JSON.serialize(new Map<String, Object>{
                'intId' => intId,
                'snapshotId' => getRunId
            });
            req.setBody(requestBody);


        // Send request
        HttpResponse res = http.send(req);
        if(res.getStatusCode() == 202){
            return true;
        }else{
            return false;
        }
        
         }  
         catch (Exception ex) {
            safeLogException(ex, 'requestSnapshot', intId);
            throw new AuraHandledException('Error fetching audit details'+ex);
           
        } 
        

    }
    
    @AuraEnabled
    public static Boolean requestAdhoc(String intId, String env){
         try{
            JobHistoryEndpointConfig__mdt config =AEHC_EnvironmentBasedUrlConfigs.getConfig(env, 'Snapshot');
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            // Endpoint
            req.setEndpoint(config.Endpoint_URL__c +'/jobId');
			req.setHeader('Content-Type', 'application/json');
			req.setMethod('POST');

            // Body (JSON)
            String requestBody = JSON.serialize(new Map<String, Object>{
                'intId' => intId
            });
            req.setBody(requestBody);


        // Send request
        HttpResponse res = http.send(req);
        if(res.getStatusCode() == 202){
            return true;
        }else{
            return false;
        }
        
         }  
         catch (Exception ex) {
            safeLogException(ex, 'requestSnapshot', intId);
            throw new AuraHandledException('Error fetching audit details'+ex);
           
        } 
        

    }
    
    private static void safeLogException(Exception ex,
                                         String operation,
                                         Id recordId) {
                                             try {
                                                 AEHC_Logger.logException(
                                                     ex,
                                                     'Apex',
                                                     'AEHC_ViewJobHistoryController',
                                                     operation,
                                                     recordId != null ? String.valueOf(recordId) : null,
                                                     'High',
                                                     'ViewJobHistory',
                                                     null,
                                                     'UAT'
                                                 );
                                             } catch (Exception ignore) {}
                                         }
    
    
    
}