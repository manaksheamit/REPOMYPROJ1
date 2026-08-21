public class AEHC_ServiceNow_Queueable implements Queueable, Database.AllowsCallouts {

    private List<Id> recordIds;

    public AEHC_ServiceNow_Queueable(List<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {

        List<Subscription__c> updates = new List<Subscription__c>();

        for (Id recId : recordIds) {

            try {

                // ✅ Call your existing Apex method
                List<String> result =
                    AEHC_ServiceNowIntegration.createRequest(
                        new List<String>{String.valueOf(recId)}
                    );

                // ✅ Get request number
                if (result != null && !result.isEmpty()) {

                    String reqNumber = result[0];

                    if (String.isNotBlank(reqNumber)) {

                        Subscription__c upd = new Subscription__c(
                            Id = recId,
                            AEHC_SNow_Request__c = reqNumber
                        );

                        updates.add(upd);
                    }
                }

            } catch (Exception ex) {

                AEHC_Logger.logException(ex,'Apex','AEHC_ServiceNow_Queueable','Callout',recId,'P1','Integration',null,System.Label.AEHC_Environment_Name);
            }
        }

        // ✅ Bulk Update
        if (!updates.isEmpty()) {
            update updates;
        }
    }
}