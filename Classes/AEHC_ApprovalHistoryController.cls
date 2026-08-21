public without sharing class AEHC_ApprovalHistoryController {
	
   
@AuraEnabled(cacheable=true)
    public static List<ApprovalHistoryWrapper> getApprovalHistory(Id recordId) {
       
        List<ApprovalHistoryWrapper> result = new List<ApprovalHistoryWrapper>();
        List<ProcessInstance> instances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :recordId
            ORDER BY CreatedDate DESC
        ];

        if (instances.isEmpty()) return result;

        // ✅ Get Steps
        List<ProcessInstanceStep> steps = [
            SELECT Id, ProcessInstanceId, StepStatus, Comments,
                   Actor.Name, OriginalActor.Name,
                   CreatedDate, StepNodeId
            FROM ProcessInstanceStep
            WHERE ProcessInstanceId IN :instances
            ORDER BY CreatedDate ASC
        ];

        // ✅ Collect StepNodeIds
        Set<Id> nodeIds = new Set<Id>();
        for (ProcessInstanceStep step : steps) {
            if (step.StepNodeId != null) {
                nodeIds.add(step.StepNodeId);
            }
        }

        // ✅ Query ProcessNode for actual Step Names
        Map<Id, String> nodeNameMap = new Map<Id, String>();
        if (!nodeIds.isEmpty()) {
            for (ProcessNode node : [
                SELECT Id, Name
                FROM ProcessNode
                WHERE Id IN :nodeIds
            ]) {
                nodeNameMap.put(node.Id, node.Name);
            }
        }

        // ✅ Build Response
        for (ProcessInstanceStep step : steps) {

            String stepName;

            if (step.StepNodeId != null && nodeNameMap.containsKey(step.StepNodeId)) {
                stepName = nodeNameMap.get(step.StepNodeId);
            } else {
                // fallback for system steps
                if (step.StepStatus == 'Started') {
                    stepName = 'Approval Request Submitted';
                } else {
                    stepName = step.StepStatus;
                }
            }

            result.add(new ApprovalHistoryWrapper(
                stepName,
                step.CreatedDate,
                step.StepStatus,
                step.OriginalActor != null ? step.OriginalActor.Name : '',
                step.Actor != null ? step.Actor.Name : '',
                step.Comments
            ));
        }

        return result;

    }

    public class ApprovalHistoryWrapper {
        @AuraEnabled public String stepName;
        @AuraEnabled public Datetime datefield;
        @AuraEnabled public String status;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public String actualApprover;
        @AuraEnabled public String comments;

        public ApprovalHistoryWrapper(String stepName, Datetime datefield, String status,
                                      String assignedTo, String actualApprover, String comments) {
            this.stepName = stepName;
            this.datefield = datefield;
            this.status = status;
            this.assignedTo = assignedTo;
            this.actualApprover = actualApprover;
            this.comments = comments;
        }
    }


}