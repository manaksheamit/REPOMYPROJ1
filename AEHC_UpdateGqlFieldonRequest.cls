public class AEHC_UpdateGqlFieldonRequest {
    
    @AuraEnabled(cacheable=true)
    public static string getGqlschemaTreeFormat() {
        try{
            //return '{"data":{"__type":{"name":"hr_segment","fields":[{"name":"etl_publn_id"},{"name":"etl_source_sys"},{"name":"etl_rec_eff_beg_ts"},{"name":"etl_rec_eff_end_ts"},{"name":"etl_rec_lst_updt_ts"},{"name":"etl_mode"},{"name":"etl_hash"},{"name":"hr_segment_code"},{"name":"effective_status_code"},{"name":"hr_segment_description"},{"name":"hr_segment_short_description"},{"name":"effective_date"}]}}}';
            String respBody ='';
            String endpoint = System.Label.AEHC_Graph_API_EndPoint;
            String query =
                'query {' + '\n' +
                '  __schema {' + '\n' +
                '    types {' + '\n' +
                '      name' + '\n' +
                '      kind' + '\n' +
                '      fields {' + '\n' +
                '        name' + '\n' +
                '        type {' + '\n' +
                '          name' + '\n' +
                '          kind' + '\n' +
                '        }' + '\n' +
                '        args {' + '\n' +
                '          name' + '\n' +
                '          type {' + '\n' +
                '            name' + '\n' +
                '            kind' + '\n' +
                '          }' + '\n' +
                '        }' + '\n' +
                '      }' + '\n' +
                '      interfaces { name }' + '\n' +
                '      possibleTypes { name }' + '\n' +
                '      enumValues { name }' + '\n' +
                '    }' + '\n' +
                '    queryType { name }' + '\n' +
                '    mutationType { name }' + '\n' +
                '    subscriptionType { name }' + '\n' +
                '    directives {' + '\n' +
                '      name' + '\n' +
                '      locations' + '\n' +
                '      args {' + '\n' +
                '        name' + '\n' +
                '        type {' + '\n' +
                '          name' + '\n' +
                '          kind' + '\n' +
                '        }' + '\n' +
                '      }' + '\n' +
                '    }' + '\n' +
                '  }' + '\n' +
                '}';
    
            // Build the JSON body safely (avoids manual escaping)
            Map<String, Object> payload = new Map<String, Object>{
                'query' => query
                // 'variables' => new Map<String, Object>{} // add if needed
            };
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(JSON.serialize(payload));
    
            HttpResponse res = new Http().send(req);  // Apex HTTP callout [7](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_restful_http.htm)
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                respBody = res.getBody();
            }
        	return respBody;    
        }
        catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_UpdateGqlFieldonRequest', 'Callout', null, 'P1', 'Integration', null, System.Label.AEHC_Environment_Name);
            return null;
        }

    }

    // Encrypt Method
    @AuraEnabled
    public static String encrypt(String plainText) {
        String secretKey = System.Label.AEHC_GraphDataEncryptionKey;
        // Convert inputs to Blob
        // Convert key to 32-byte array for AES-256
        Blob key = Crypto.generateDigest('SHA-256', Blob.valueOf(secretKey));

        // Encrypt the data with AES-256, IV managed automatically
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', key, Blob.valueOf(plainText));

        // Convert encrypted data to Base64 for storage/display
        String encryptedBase64 = EncodingUtil.base64Encode(encryptedData);
        String keyString = EncodingUtil.base64Encode(key);
        // Convert to Base64
        return keyString+'.'+encryptedBase64;
    }


    // Decrypt Method
    @AuraEnabled
    public static String decrypt(String encryptedBase64) {
        String secretKey = System.Label.AEHC_GraphDataEncryptionKey;
        Blob key = Crypto.generateDigest('SHA-256', Blob.valueOf(secretKey));
        //Decrypt
        Blob encryptedBlobFromString = EncodingUtil.base64Decode(encryptedBase64);
        Blob decryptedBlob = Crypto.decryptWithManagedIV('AES256', key, encryptedBlobFromString);
        String decryptedData = decryptedBlob.toString();
        return decryptedData;
    }



    public class ParsedResult {
        @AuraEnabled
        public String objName;
        @AuraEnabled
        public List<String> selectedFields;
    }
}