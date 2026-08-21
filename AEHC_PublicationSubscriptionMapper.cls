/**
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
* Class Name      : AEHC_PublicationSubscriptionMapper
* Author          : Parvej Alam
* Created Date    : May 21, 2026
* Last Modified By: Parvej
* Last Modified On: May 21, 2026
* Description     : This class implements for fieldsmapping for publications/subscription job.
*  
* Change History  :
*  Date          │   Author     │   Change
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*  May 21, 2026  │ <YourName>   │ Initial version
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*/

public without sharing class AEHC_PublicationSubscriptionMapper {
    public static final Integer DEFAULT_BATCHSIZE = 20;
    public static final Integer DEFAULT_FILESIZE = 5;
    public static Map<String, Object> subScriptionMapping(string recordId, Boolean isJobEnable) {
        
        AEHC_Asset__c asset = [
            SELECT Id, 
            Name,
            AEHC_Application_Id__c,
            AEHC_Destination_Type__c,
            AEHC_Subscription_Request__c,
            AEHC_Subscription_Request__r.Name,
            AEHC_Publication_Description__c,
            AEHC_Publication__c,
            AEHC_Publication__r.AEHC_Publication_Type__c,
            AEHC_Publication__r.AEHC_Schema_Name__c,
            AEHC_Publication__r.AEHC_Table_Name__c,
            AEHC_Publication__r.AEHC_Publication_Description__c,
            AEHC_Publication__r.AEHC_Application__c,
            AEHC_Publication__r.AEHC_Application__r.Name,
            AEHC_Publication__r.Name,
            CreatedBy.Name,
            AEHC_Description__c,
            AEHC_Schedule_Summary__c,
            AEHC_VSchedule__c,
            AEHC_CRON_Job_Expression__c,
            AEHC_Storage_Account_Bucket__c,
            AEHC_Container_Folder_Path__c,
            AEHC_Database_Type__c,
            AEHC_Host_Server__c,
            AEHC_Port__c,
            AEHC_Other_Properties__c,
            AEHC_On_Initialization__c,
            AEHC_On_Success__c,
            AEHC_On_Load__c,
            AEHC_On_Error__c,
            AEHC_Mute_Error_Flag__c,
            AEHC_Batch_Flag__c,
            AEHC_Remote_Directory_Path__c,
            AEHC_Filename__c,
            AEHC_Output_Format__c,
            AEHC_Selected_Fields_JSON__c,
            AEHC_Delimiter__c,
            AEHC_Include_Header__c,
            AEHC_Transformation_ID__c,
            AEHC_BatchSize__c,
            AEHC_Notes__c,
            AEHC_Table_Name__c,
            AEHC_Schema_Name__c,
            AEHC_MaxFileSize__c,
            AEHC_Publication_Type__c,
            AEHC_JDBC_URL__c,
            AEHC_Environment__c,
            AEHC_Is_Subscription__c,
            AEHC_Subscription_Request__r.AEHC_Consumming_Application__r.Name,
            AEHC_IntId__c,
            AEHC_CreatedByNameEmail__c
            FROM AEHC_Asset__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
       AEHC_AssetMember__c assetMember;
       if (asset.Id != null) {
            List<AEHC_AssetMember__c> assetMembers = [
                SELECT Id,AEHC_BusinessOwner__c
                FROM AEHC_AssetMember__c
                WHERE AEHC_Role__c = 'Business Owner'
                AND AEHC_Asset__c = :asset.AEHC_Publication__r.AEHC_Application__c
                LIMIT 1
            ];
            if (!assetMembers.isEmpty()) {
                assetMember = assetMembers[0];
            }
        }
        
        
        AEHC_Asset__c subMonAsset;
        List<AEHC_Asset__c> pubJobId = [SELECT Id, AEHC_IntId__c
                                        FROM AEHC_Asset__c
                                        WHERE (AEHC_Publication__c = :asset.AEHC_Publication__c OR Id = :asset.AEHC_Publication__c)
                                        AND AEHC_Is_Active__c = true AND AEHC_Environment__c =: asset.AEHC_Environment__c
                                        AND AEHC_Is_Subscription__c = false
                                        AND RecordType.DeveloperName = 'AEHC_Version' LIMIT 1];
        if (!pubJobId.isEmpty()) {
            subMonAsset = pubJobId[0];
        }
        
        
        // -------- CRON --------
        
        Map<String, Object> scheduleMap = new Map<String, Object>{
            'minutes' => '',
                'hours' => '',
                'dayOfMonth' => '',
                'month' => '',
                'dayOfWeek' => ''
                };
                    
                    if (!String.isBlank(asset.AEHC_CRON_Job_Expression__c)) {
                        
                        List<String> cronList = asset.AEHC_CRON_Job_Expression__c.split(';');
                        List<String> dayOfWeeks = new List<String>();
                        Boolean isFirstCronProcessed = false;
                        
                        for (String cronExp : cronList) {
                            cronExp = cronExp.trim();
                            
                            // Handle one or more spaces between fields
                            List<String> c = cronExp.split('\\s+');
                            
                            // Support both 6-field and 7-field cron expressions
                            if (c.size() == 6 || c.size() == 7) {
                                
                                // Take common values from first cron only
                                if (!isFirstCronProcessed) {
                                    scheduleMap.put('minutes', c[1]);
                                    scheduleMap.put('hours', c[2]);
                                    scheduleMap.put('dayOfMonth', c[3]);
                                    scheduleMap.put('month', c[4]);
                                    isFirstCronProcessed = true;
                                }
                                
                                // Process dayOfWeek for each cron
                                String dow = c[5];
                                
                                if (dow.contains('#')) {
                                    dow = dow.substring(0, dow.indexOf('#'));
                                }
                                
                                // Add all values (* and ?) for now
                                if (!String.isBlank(dow)) {
                                    dayOfWeeks.add(dow);
                                }
                            }
                        }
                        
                        // Final handling of dayOfWeek
                        if (!dayOfWeeks.isEmpty()) {
                            
                            if (dayOfWeeks.size() == 1) {
                                // Single cron → keep '*' or '?' as-is
                                scheduleMap.put('dayOfWeek', dayOfWeeks[0]);
                            } else {
                                // Multi cron → remove '*' and '?'
                                List<String> filteredDays = new List<String>();
                                
                                for (String d : dayOfWeeks) {
                                    if (d != '?' && d != '*') {
                                        filteredDays.add(d);
                                    }
                                }
                                
                                scheduleMap.put('dayOfWeek', String.join(filteredDays, ','));
                            }
                        }
                    }
        
        
        
        // -------- STORAGE --------
        String endpoint = '';
        String storageAccountName = '';
        String storageValue = asset.AEHC_Storage_Account_Bucket__c;
        if (!String.isBlank(storageValue)) {
            storageValue = storageValue.trim().removeEnd('/');
            
            // Case 1: Full URL (contains protocol like http/https)
            if (storageValue.startsWithIgnoreCase('http')) {
                List<String> parts = storageValue.split('/');
                
                if (parts.size() >= 4) {
                    // Example: https://account.blob.core.windows.net/container
                    endpoint = parts[0] + '//' + parts[2];   // https://account.blob.core.windows.net
                    storageAccountName = parts[2].split('\\.')[0]; // extract "account"
                }
            }
            // Case 2: Only storage account name
            else {
                storageAccountName = storageValue;
                endpoint = ''; // leave blank
            }
        }
        
        
        // -------- JDBC --------
        String instanceName = '';
        String databaseName = '';
        String serviceName = '';
        
        if (!String.isBlank(asset.AEHC_JDBC_URL__c)) {
            for (String part : asset.AEHC_JDBC_URL__c.split(';')) {
                List<String> kv = part.split('=');
                if (kv.size() == 2) {
                    if (kv[0] == 'instanceName') instanceName = kv[1];
                    if (kv[0] == 'databaseName') databaseName = kv[1];
                    if (kv[0] == 'serviceName') serviceName = kv[1];
                }
            }
        }
        
        // -------- FINAL MAP --------
        Map<String, Object> result = new Map<String, Object>(); 
        if(asset.AEHC_Is_Subscription__c == true){
            result.put('applicationName', nvl(asset.AEHC_Subscription_Request__r.AEHC_Consumming_Application__r.Name));
            result.put('jobType', 'Subscriber');
            result.put('jobName', nvl(asset.AEHC_Publication__r.Name));
            result.put('pubIntId', subMonAsset.AEHC_IntId__c);
            if(asset.AEHC_IntId__c != null){
                result.put('intId', asset.AEHC_IntId__c);
            }
        }else{
            result.put('applicationName', nvl(asset.AEHC_Publication__r.AEHC_Application__r.Name));
            result.put('jobType', 'Publisher');
            result.put('jobName', nvl(asset.AEHC_Publication__r.Name));
            if(asset.AEHC_IntId__c != null){
                result.put('intId', asset.AEHC_IntId__c);
            }
        }
        
        Boolean isSubMon = 'Submon (Triggered on Publication Completion)'
            .equals(asset.AEHC_VSchedule__c);
        
        Map<String, Object> appJobConfig = new Map<String, Object>();
        
        // Always needed fields (if you want them always)
        if (!String.isBlank(asset.AEHC_Description__c)) {
            appJobConfig.put('description', asset.AEHC_Description__c);
        }
        
        String businessOwnerName = assetMember?.AEHC_BusinessOwner__c?.split(',')[0];
        String businessOwnerEmail =assetMember?.AEHC_BusinessOwner__c?.split(',')[1];
        
        String jobOwnerName = asset?.AEHC_CreatedByNameEmail__c?.split(',')[0];
        String jobOwnerEmail = asset?.AEHC_CreatedByNameEmail__c?.split(',')[1];
        String jobDesc;
        appJobConfig.put('applicationOwner', businessOwnerName);
        appJobConfig.put('jobOwner', jobOwnerName);
        appJobConfig.put('applicationOwnerEmail', businessOwnerEmail);
        appJobConfig.put('jobOwnerEmail', jobOwnerEmail);
        
        if(asset.AEHC_Is_Subscription__c == true){
            jobDesc = asset.AEHC_Publication__r ?.AEHC_Publication_Description__c;  
        }else{
            jobDesc = asset.AEHC_Publication_Description__c;
        }
        if (!String.isBlank(jobDesc)) {
            appJobConfig.put('jobDescription', jobDesc);
        }
        appJobConfig.put('scheduleName', String.isBlank(asset.AEHC_Schedule_Summary__c) ? 'Run as publisher schedule' : asset.AEHC_Schedule_Summary__c);
        
        // scheduleMap (if not null / empty)
        if (scheduleMap != null && !scheduleMap.isEmpty() && isSubMon == False) {
            appJobConfig.put('schedule', scheduleMap);
        }
        
        // ✅ SubMon fields ONLY if true
        if (isSubMon) {
            appJobConfig.put('subMonFlag', true);
            appJobConfig.put('subMonIntId', subMonAsset.AEHC_IntId__c);
            
        }else{
            appJobConfig.put('subMonFlag', false);
        }
        appJobConfig.put('activeFlag', isJobEnable);
        
        // Finally attach to result
        result.put('applicationJobConfig', appJobConfig);
        // -------- blobConfig --------
        
        if (asset.AEHC_Destination_Type__c == 'BLOB') {
            
            Map<String, Object> blobConfig = new Map<String, Object>();
            
            if (!String.isBlank(endpoint)) {
                blobConfig.put('endpoint', endpoint);
            }
            
            if (!String.isBlank(storageAccountName)) {
                blobConfig.put('storageAccountName', storageAccountName);
            }
            
            String container = asset.AEHC_Container_Folder_Path__c;
            if (!String.isBlank(container)) {
                blobConfig.put('containerName', container);
            }
            
            // Only add blobConfig if at least one field exists
            if (!blobConfig.isEmpty()) {
                result.put('blobConfig', blobConfig);
            }
        }
        
        // -------- dbConfig --------
        if (asset.AEHC_Destination_Type__c == 'Database'){
            result.put('dbConfig', new Map<String, Object>{
                'hostName' => nvl(asset.AEHC_Host_Server__c),
                    'port' => nvl(asset.AEHC_Port__c),
                    'instanceName' => nvl(instanceName),
                    'databaseName' => nvl(databaseName),
                    'serviceName' => nvl(serviceName),
                    'otherProperties' => nvl(asset.AEHC_Other_Properties__c),
                    'onInitSP' => nvl(asset.AEHC_On_Initialization__c),
                    'onLoadSP' => nvl(asset.AEHC_On_Load__c),
                    'onSuccessSP' => nvl(asset.AEHC_On_Success__c),
                    'onErrorSP' => nvl(asset.AEHC_On_Error__c),
                    'muteErrorFlag' => nvlBool(asset.AEHC_Mute_Error_Flag__c),
                    'batchFlag' => nvlBool(asset.AEHC_Batch_Flag__c),
                    'notes' => nvl(asset.AEHC_Notes__c)
                    });
        }
        
        
        // -------- sftpConfig --------
        if (asset.AEHC_Destination_Type__c == 'SFTP'){
            result.put('sftpConfig', new Map<String, Object>{
                'hostName' => nvl(asset.AEHC_Host_Server__c),
                    'port' => nvl(asset.AEHC_Port__c),
                    'remoteBasePath' => nvl(asset.AEHC_Remote_Directory_Path__c),
                    'remotePath' => nvl(asset.AEHC_Remote_Directory_Path__c),
                    'fileNamePattern' => nvl(asset.AEHC_Filename__c),
                    'fileFormat' => nvl(asset.AEHC_Output_Format__c),
                    'csvHeaderInclusionFlag' => nvlBool(asset.AEHC_Include_Header__c),
                    'fileFilter' => nvl('.'+asset.AEHC_Output_Format__c)
                    //'fileOutputFormat' => nvl(asset.AEHC_Output_Format__c)
                   // 'csvCustomHeaderRow' => getLabelsWithDelimiter(asset.AEHC_Selected_Fields_JSON__c, asset.AEHC_Delimiter__c),
                   // 'csvInputDelimiter' => nvl(asset.AEHC_Delimiter__c),
                   // 'csvOutputDelimiter' => nvl(asset.AEHC_Delimiter__c)
                    });
        }
        
        
        // -------- parserConfig --------
        
        Map<String, Object> parserConfig = new Map<String, Object>();
        if(asset.AEHC_Is_Subscription__c == true){
            String transformScriptId = asset.AEHC_Transformation_ID__c;
            String subscriptionFields;
            parserConfig.put('csvCustomHeaderRow', getLabelsWithDelimiter(asset.AEHC_Selected_Fields_JSON__c, asset.AEHC_Delimiter__c));
            parserConfig.put('isHeaderAvailable', nvlBool(asset.AEHC_Include_Header__c));
            parserConfig.put('encoding', 'UTF-8');
            parserConfig.put('inputDelimiter', ',');
            parserConfig.put('outputDelimiter', nvl(asset.AEHC_Delimiter__c));
            parserConfig.put('valuesQuoted', true);
            parserConfig.put('xmlRootNodeName', 'root');
            parserConfig.put('xmlRecordNodeName', 'record');
            parserConfig.put('xmlFieldsAsAttributes', false);

            if (!String.isBlank(transformScriptId)) {
                parserConfig.put('transformScriptId', transformScriptId);
            }
            if (String.isNotBlank(asset.AEHC_Selected_Fields_JSON__c)) {
                
                // First try fieldName
                subscriptionFields = getFieldssWithDelimiter(asset.AEHC_Selected_Fields_JSON__c, '|');
                
                // If fieldName not found, try name
                if (String.isBlank(subscriptionFields)) {
                    subscriptionFields = getFieldssWithName(asset.AEHC_Selected_Fields_JSON__c,'|');
                }
                
                // If still blank, use label
                if (String.isBlank(subscriptionFields)) {
                    subscriptionFields = getLabelsWithDelimiter(asset.AEHC_Selected_Fields_JSON__c, '|');
                }
            }
            if (!String.isBlank(subscriptionFields)) {
                parserConfig.put('subscriptionFields', subscriptionFields);
            }
            
            // Only add batchSize if it has a value (or you deliberately want default logic)
            if (asset.AEHC_BatchSize__c != null) {
                parserConfig.put('batchSize', asset.AEHC_BatchSize__c);
            }
            // If you still want default = 5 BUT only when explicitly needed, use below instead:
            if (asset.AEHC_BatchSize__c != null) {
                parserConfig.put('batchSize', asset.AEHC_BatchSize__c);
            }
            else {
                parserConfig.put('batchSize', DEFAULT_BATCHSIZE);
            }
            // Add to result only if something exists
            if (!parserConfig.isEmpty()) {
                result.put('parserConfig', parserConfig);
            }
        }
        
        
        // -------- adbConfig --------
        if(asset.AEHC_Is_Subscription__c != true){
            String selectQuery = generateSelectQuery(asset.AEHC_Selected_Fields_JSON__c, asset.AEHC_Publication__r != null
                                                 ? asset.AEHC_Publication__r.AEHC_Schema_Name__c : asset.AEHC_Schema_Name__c, asset.AEHC_Publication__r != null
                                                 ? asset.AEHC_Publication__r.AEHC_Table_Name__c : asset.AEHC_Table_Name__c);
            result.put('adbConfig', new Map<String, Object>{
                'publicationType' => asset.AEHC_Publication__r.AEHC_Publication_Type__c,
                    'tableName' => asset.AEHC_Publication__r != null
                    ? nvl(asset.AEHC_Publication__r.AEHC_Table_Name__c)
                    : nvl(asset.AEHC_Table_Name__c),
                        'schemaName' => asset.AEHC_Publication__r != null
                        ? nvl(asset.AEHC_Publication__r.AEHC_Schema_Name__c)
                        : nvl(asset.AEHC_Schema_Name__c),
                            'maxFileSize' => asset.AEHC_MaxFileSize__c == null ? DEFAULT_FILESIZE : asset.AEHC_MaxFileSize__c,
                                'query' => selectQuery
                                
                                });
            
        }
        
        
        return result;
    }
    
    
    // -------- Helper Methods --------
    private static String nvl(Object val) {
        return val == null ? '' : String.valueOf(val);
    }
    
    private static Boolean nvlBool(Boolean val) {
        return val == null ? false : val;
    }
    
    
    
    
    public static String getLabelsWithDelimiter(String jsonString, String outputDelimiter) {
        if (String.isBlank(jsonString)) {
            return '';
        }
        
        Object parsed = JSON.deserializeUntyped(jsonString);
        if (!(parsed instanceof List<Object>)) {
            return '';
        }
        
        List<Object> records = (List<Object>) parsed;
        List<String> labels = new List<String>();
        
        for (Object obj : records) {
            Map<String, Object> mapRecord = (Map<String, Object>) obj;
            if (mapRecord.containsKey('label') && mapRecord.get('label') != null) {
                labels.add(String.valueOf(mapRecord.get('label')));
            }
        }
        String delim = String.isBlank(outputDelimiter) ? ',' : outputDelimiter;
        return String.join(labels, delim);
    }
    
    public static String getFieldssWithName(String jsonString, String outputDelimiter) {
        if (String.isBlank(jsonString)) {
            return '';
        }
        
        Object parsed = JSON.deserializeUntyped(jsonString);
        if (!(parsed instanceof List<Object>)) {
            return '';
        }
        
        List<Object> records = (List<Object>) parsed;
        List<String> labels = new List<String>();
        
        for (Object obj : records) {
            Map<String, Object> mapRecord = (Map<String, Object>) obj;
            if (mapRecord.containsKey('name') && mapRecord.get('name') != null) {
                labels.add(String.valueOf(mapRecord.get('name')));
            }
        }
        String delim = String.isBlank(outputDelimiter) ? '|' : outputDelimiter;
        return String.join(labels, delim);
    }
    
    public static String getFieldssWithDelimiter(String jsonString, String outputDelimiter) {
        if (String.isBlank(jsonString)) {
            return '';
        }
        
        Object parsed = JSON.deserializeUntyped(jsonString);
        if (!(parsed instanceof List<Object>)) {
            return '';
        }
        
        List<Object> records = (List<Object>) parsed;
        List<String> labels = new List<String>();
        
        for (Object obj : records) {
            Map<String, Object> mapRecord = (Map<String, Object>) obj;
            
            if (mapRecord.containsKey('fieldName') && mapRecord.get('fieldName') != null) {
                labels.add(String.valueOf(mapRecord.get('fieldName')));
            }
        }
        String delim = String.isBlank(outputDelimiter) ? '|' : outputDelimiter;
        return String.join(labels, delim);
    }
    
    public static String generateSelectQuery(String jsonString,String schemaName,String tableName) {
        if (String.isBlank(jsonString) ||
            String.isBlank(schemaName) ||
            String.isBlank(tableName)) {
                return '';
            }
        
        Object parsed = JSON.deserializeUntyped(jsonString);
        if (!(parsed instanceof List<Object>)) {
            return '';
        }
        
        List<String> selectFields = new List<String>();
        for (Object obj : (List<Object>)parsed) {
            Map<String, Object> fieldMap = (Map<String, Object>)obj;
            String fieldName = (String)fieldMap.get('fieldName');
            String labelName = (String)fieldMap.get('labelName');
            
            if (String.isBlank(fieldName)) {
                continue;
            }
            
            // If labelName is blank, use fieldName
            labelName = String.isBlank(labelName) ? fieldName.toUpperCase() : labelName.toUpperCase();
            selectFields.add(fieldName + ' as ' + labelName);
        }
        
        if (selectFields.isEmpty()) {
            return '';
        }
        
        return 'SELECT ' + String.join(selectFields, ' , ') + ' FROM ' + schemaName + '.' + tableName;
    } 
}