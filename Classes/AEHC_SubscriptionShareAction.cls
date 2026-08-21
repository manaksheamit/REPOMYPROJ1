public class AEHC_SubscriptionShareAction {
    
    public class Input {
        
        @InvocableVariable(required=true)
        public String accRecId;
        
        @InvocableVariable
        public List<String> userContactIds;
    }
    
    @InvocableMethod(label='Subscription:Share')
    public static void shareSubscription(List<Input> inputs) {
        
        List<AccountContactRelation> acrRecs = new List<AccountContactRelation>();
        for (Input inp : inputs) {
            
            for(String userContactId : inp.userContactIds) {
                acrRecs.add(new AccountContactRelation(
                    AccountId = inp.accRecId,
                    ContactId = userContactId
                ));
            }
            
        }
        
        if(!acrRecs.isEmpty()) {
            AEHC_Utility.upsertRecs(acrRecs);
        }
    }
    
}