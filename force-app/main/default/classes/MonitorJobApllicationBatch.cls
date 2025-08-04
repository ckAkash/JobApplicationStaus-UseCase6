/**
 * @description       : 
 * @author            : Akash Yadav
 * @group             : 
 * @last modified on  : 08-03-2025
 * @last modified by  : Akash Yadav
**/
global with sharing class MonitorJobApllicationBatch implements Database.Batchable<sObject>{
    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    * @return Database.QueryLocator 
    **/
    global Database.QueryLocator start(Database.BatchableContext batchContext){
        return Database.getQueryLocator([
                                        SELECT Id, 
                                                Status__c,
                                                Last_Activity_Date__c, 
                                                Last_Interview_Date__c, 
                                                Candidate_No_Longer_Interested__c
                                        FROM Job_Application__c
                                        WHERE Status__c IN ('Withdrawn','Inactive','Not Selected')
       ]);
    }

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    * @param scope 
    **/
    global void execute(Database.BatchableContext batchContext, List<SObject> scope){
        List<Job_Application__c> applicationToUpdate = new List<Job_Application__c>();
        
        Map<String,Candidate_Applicant_Metadata__mdt> rulesMap = new Map<String,Candidate_Applicant_Metadata__mdt>();
        for(Candidate_Applicant_Metadata__mdt rule: [SELECT RuleName__c,
                                                            DaysSinceLastActivity__c,
                                                            DaysSinceInterview__c,
                                                            CurrentStatus__c,
                                                            Candidate_no_longer_interested__c,
                                                            NewStatus__c	,
                                                            Active__c
                                                    FROM Candidate_Applicant_Metadata__mdt
                                                    WHERE Active__c=TRUE
        ]){
            rulesMap.put(rule.RuleName__c,rule);
        }

        for(Job_Application__c jobApplication: (List<Job_Application__c>) scope){
            applyStatusUpdateRulesHelper(jobApplication, rulesMap, applicationToUpdate);
        }

        if(!applicationToUpdate.isEmpty()){
            update as user applicationToUpdate;
        }

    }

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    **/
    global void finish(Database.BatchableContext batchContext){
        // execute any post-processing operations
        System.debug(LoggingLevel.INFO, 'Successfully processed all records');
    }
    

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param applicant 
    * @param rulesMap 
    * @param toUpdate 
    **/
    private void applyStatusUpdateRulesHelper(Job_Application__c applicant, Map<String, Candidate_Applicant_Metadata__mdt> rulesMap,List<Job_Application__c> toUpdate) {
        Date today = Date.today();
        String newStatus = getInactiveStatus(applicant, rulesMap.get('Inactive Applicant Rule'), today);
        if (newStatus == null) {
            newStatus = getNotSelectedStatus(applicant, rulesMap.get('Not Selected After Interview Rule'), today);
        }
        if (newStatus == null) {
            newStatus = getWithdrawnStatus(applicant, rulesMap.get('Application Withdrawn Rule'));
        }

        if (newStatus != null && applicant.Status__c != newStatus) {
            applicant.Status__c = newStatus;
            toUpdate.add(applicant);
        }
    }

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param app 
    * @param rule 
    * @param today
    * @return String 
    **/
    private String getInactiveStatus(Job_Application__c app, Candidate_Applicant_Metadata__mdt rule,Date today) {
        if (rule == null || rule.DaysSinceLastActivity__c == null || app.Last_Activity_Date__c == null) {
            return null;
        }
        Integer days = today.daysBetween(app.Last_Activity_Date__c);
        if (days >= rule.DaysSinceLastActivity__c) {
            return rule.NewStatus__c;
        }
        return null;
    }

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param app 
    * @param rule 
    * @param today
    * @return String 
    **/
    private String getNotSelectedStatus(Job_Application__c app, Candidate_Applicant_Metadata__mdt rule, Date today) {
        if (rule == null || rule.DaysSinceInterview__c == null || app.Last_Interview_Date__c == null) {
            return null;
        }
        Integer days = today.daysBetween(app.Last_Interview_Date__c);
        if (days >= rule.DaysSinceInterview__c) {
            return rule.NewStatus__c;
        }
        return null;
    }

    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param app 
    * @param rule 
    * @return String 
    **/
    private String getWithdrawnStatus(Job_Application__c app, Candidate_Applicant_Metadata__mdt rule) {
        if (rule == null || app.Candidate_No_Longer_Interested__c != true) {
            return null;
        }
        return rule.NewStatus__c;
    }
}
