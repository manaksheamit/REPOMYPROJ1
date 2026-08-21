/**
 * @description AEHC_Mule_FetchAPIDetails provides a Flow-invocable operation to fetch additional API details
 *              (specifically label values) from MuleSoft Exchange for a given API name.
 *              This class makes an HTTP callout to the configured named credential endpoint and returns
 *              a list of label strings wrapped in an outer list to satisfy the Invocable method contract.
 * @author AEH
 * @group Integration
 * @since 1.0
 */
public class AEHC_Mule_FetchAPIDetails {
    /**
     * @description Invocable method to retrieve additional API details (labels) from MuleSoft Exchange.
     *              Expects the first element of apiName to be the target API identifier.
     *              Returns a list containing a single list of label strings when available; otherwise an empty outer list.
     * @param apiName A single-element list containing the API name (identifier) to fetch details for.
     * @return List<List<String>> An outer list wrapping a list of label values returned by MuleSoft Exchange.
     */
    @InvocableMethod
    //method to fetch api details from mulesoft
    public static List<List<String>> getAPIsAdditionalDetails(List<String> apiName){
        try{
        String resp;
        List<String> labels = new List<String>();    
        String contactEmail = '';
        String contactName  = '';
        String assetType = '';
        List<List<String>> labelsList = new List<List<String>>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:MulesoftExchangeApi/assets/9d1390e4-8f9f-406d-a404-a34085c57f2d/' + apiName[0] + '/asset');
        request.setMethod('GET');
        request.setTimeout(120000);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            resp = response.getBody();
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(resp);
            List<Object> rawLabels = (List<Object>) m.get('labels');            
            for (Object o : rawLabels) {
                labels.add((String) o);
            }
			contactEmail = (String) m.get('contactEmail');
            labels.add('contactEmail:'+(contactEmail==null?'':contactEmail));
        	contactName  = (String) m.get('contactName');
            labels.add('contactName:'+(contactName==null?'':contactName));
            assetType  = (String) m.get('type');
            labels.add('assetType:'+(assetType==null?'':assetType));
        }
        if (labels != null) {
            labelsList.add(labels);
        }
        return labelsList;
        }catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_Mule_FetchAPIDetails', 'Callout', null, 'P1', 'Integration', null, 'Dev');
            return null;
        }
      }
}