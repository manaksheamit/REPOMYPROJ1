public without sharing class AEHC_EnvironmentBasedUrlConfigs {
    
    public static JobHistoryEndpointConfig__mdt getConfig(String env, String jobType) {
        try{
            Map<String, JobHistoryEndpointConfig__mdt> configMap = JobHistoryEndpointConfig__mdt.getAll();
            for (JobHistoryEndpointConfig__mdt cfg : configMap.values()) {
                if (cfg.Environment__c == env && cfg.JobType__c == jobType) {
                    return cfg;
                }
            }
        }catch(Exception ex){
            system.debug('@@@ Excaption'+ex);
        }
        return null;
    }
    
}