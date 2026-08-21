/**
 * @author Asif Ahmad
 * @date 26May2026
 * @description to behave as Controller of LWC, where it provides Records as per given params
*/
public with sharing class AEHC_RecordDetailCtrl {
    
    @AuraEnabled
    public static Map<String, Object> getRecord(String sObjectName, String fieldNames, String matchFieldName, String recordId) {
        Map<String, Object> response = new Map<String, Object>();
        Map<String, Object> data = new Map<String, Object>();
        try {
            // Validate inputs
            if (String.isBlank(sObjectName) || 
                String.isBlank(fieldNames) || 
                String.isBlank(matchFieldName) || 
                String.isBlank(recordId)) {
                    
                    throw new AuraHandledException('Missing required parameters');
                }
            
            // Build dynamic WHERE condition
            String query = 'SELECT ' + fieldNames +
                ' FROM ' + sObjectName +
                ' WHERE ' + matchFieldName + ' = :recordId LIMIT 1';
            
            // Execute query
            List<SObject> records = Database.query(query);
            
            if(records.isEmpty()) {
                response.put('status', 404);
                return response;
            }
            
            response.put('status', 200);
            response.put('data', records[0]);
            return response;
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_RecordDetailCtrl.searchApplication', 'query', null, 'P1', null, null, 'Dev');
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }

}