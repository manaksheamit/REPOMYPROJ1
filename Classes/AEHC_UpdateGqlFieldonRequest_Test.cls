@isTest
public class AEHC_UpdateGqlFieldonRequest_Test {

    // Mock Class for Callout
    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Mock GraphQL response
            res.setBody('{"data":{"__schema":{"types":[{"name":"TestType"}]}}}');
            return res;
        }
    }

    // Test getGqlschemaTreeFormat (Callout)
    @isTest
    static void testGetGqlschemaTreeFormat() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        String result = AEHC_UpdateGqlFieldonRequest.getGqlschemaTreeFormat();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
        System.assert(result.contains('data'), 'Response should contain data');
    }

    // Test Encrypt Method
    @isTest
    static void testEncrypt() {

        String input = 'test123';

        Test.startTest();
        String encrypted = AEHC_UpdateGqlFieldonRequest.encrypt(input);
        Test.stopTest();

        System.assertNotEquals(null, encrypted, 'Encrypted value should not be null');
        System.assert(encrypted.contains('.'), 'Encrypted value should contain dot separator');

        // Split verification
        List<String> parts = encrypted.split('\\.');
        System.assertEquals(2, parts.size(), 'Should contain key and encrypted data');
    }

    // Test Decrypt Method
    @isTest
    static void testDecrypt() {

        String input = 'test123';

        // First encrypt
        String encryptedCombined = AEHC_UpdateGqlFieldonRequest.encrypt(input);

        // Split to pass only encrypted part (as your decrypt expects)
        String encryptedPart = encryptedCombined.split('\\.')[1];

        Test.startTest();
        String decrypted = AEHC_UpdateGqlFieldonRequest.decrypt(encryptedPart);
        Test.stopTest();

        System.assertEquals(input, decrypted, 'Decrypted value should match original');
    }

    // Test Decrypt Failure Scenario
    @isTest
    static void testDecryptInvalidInput() {

        Boolean exceptionThrown = false;

        try {
            AEHC_UpdateGqlFieldonRequest.decrypt('invalid-data');
        } catch (Exception e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid input');
    }

    // Test Callout Exception Handling
    class MockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error');
            return res;
        }
    }

}