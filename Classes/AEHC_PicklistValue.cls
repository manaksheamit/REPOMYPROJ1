public class AEHC_PicklistValue {
        @AuraEnabled @InvocableVariable
        public String label;
        @AuraEnabled @InvocableVariable
        public String value;
        public AEHC_PicklistValue(){}
        public AEHC_PicklistValue(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }