/**
 * @description       : Monitor Job Application Batch - Fixed Version
 * @author            : Akash Yadav
 * @group             : 
 * @last modified on  : 08-06-2025
 * @last modified by  : Akash Yadav
**/
global with sharing class ApplicantStatusUpdateBatch implements Database.Batchable<sObject>, Schedulable{
    
    /**
    * @description Start method 
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    * @return Database.QueryLocator 
    **/
    global Database.QueryLocator start(Database.BatchableContext batchContext){

        try {
            return Database.getQueryLocator([
            SELECT Id, 
                   Status__c,
                   Last_Activity_Date__c, 
                   Last_Interview_Date__c,
                   Candidate__c,
                   Candidate__r.Candidate_No_Longer_Interested__c,
                   (SELECT Interview_Date__c FROM Job_Interview_Details__r ORDER BY Interview_Date__c DESC LIMIT 1)
            FROM Job_Application__c
            WHERE Status__c NOT IN ('Withdrawn','Inactive','Not Selected')
            LIMIT 50
        ]);
        } catch (Exception e) {
            throw new MyCustomException(e,'Exception Occured in ApplicationUpdateBatch: Start() method.');
        }
    }

    /**
    * @description Execute method 
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    * @param scope 
    **/
    global void execute(Database.BatchableContext batchContext, List<SObject> scope){
        List<Job_Application__c> applicationToUpdate = new List<Job_Application__c>();
        
        // Get rules from custom metadata
        Map<String,Candidate_Applicant_Metadata__mdt> rulesMap = new Map<String,Candidate_Applicant_Metadata__mdt>();
        for(Candidate_Applicant_Metadata__mdt rule: [SELECT RuleName__c,
                                                            DaysSinceLastActivity__c,
                                                            DaysSinceInterview__c,
                                                            CurrentStatus__c,
                                                            Candidate_no_longer_interested__c,
                                                            NewStatus__c,
                                                            Active__c
                                                    FROM Candidate_Applicant_Metadata__mdt
                                                    WHERE Active__c=TRUE
        ]){
            rulesMap.put(rule.RuleName__c, rule);
        }

        // Process each job application
        for(Job_Application__c jobApplication: (List<Job_Application__c>) scope){
            applyStatusUpdateRulesHelper(jobApplication, rulesMap, applicationToUpdate);
        }

        if(!applicationToUpdate.isEmpty()){
            try {
                Database.update(applicationToUpdate, false);
            } catch(Exception e) {
                throw new MyCustomException(e,'Error occured while updating job applications');
            }
        }
    }

    /**
    * @description Finish method
    * @author Akash Yadav | 08-03-2025 
    * @param batchContext 
    **/
    global void finish(Database.BatchableContext batchContext){
        return;
    }
    
    /**
    * @description Helper method to apply status update rules 
    * @author Akash Yadav | 08-03-2025 
    * @param applicant 
    * @param rulesMap 
    * @param toUpdate 
    **/
    private void applyStatusUpdateRulesHelper(Job_Application__c applicant, Map<String, Candidate_Applicant_Metadata__mdt> rulesMap, List<Job_Application__c> toUpdate) {

        String newStatus = '';
        Date today = Date.today();
        newStatus = getWithdrawnStatus(applicant, rulesMap.get('Application Withdrawn Rule'));
        if (newStatus == null) {
            newStatus = getInactiveStatus(applicant, rulesMap.get('Inactive Applicant Rule'), today);
        }
        if (newStatus == null) {
            newStatus = getNotSelectedStatus(applicant, rulesMap.get('Not Selected After Interview Rule'), today);
        }
        if (newStatus != null && applicant.Status__c != newStatus) {
            applicant.Status__c = newStatus;
            toUpdate.add(applicant);
        }
    }

    /**
    * @description Check if inactive application should be updated
    * @author Akash Yadav | 08-03-2025 
    * @param app 
    * @param rule 
    * @param today
    * @return String 
    **/
    private String getInactiveStatus(Job_Application__c app, Candidate_Applicant_Metadata__mdt rule, Date today) {
        if (rule == null || rule.DaysSinceLastActivity__c == null || app.Last_Activity_Date__c == null) {
            return null;
        }
        Integer daysSinceLastActivity;
        if(app.Last_Activity_Date__c!=null){
            daysSinceLastActivity = app.Last_Activity_Date__c.daysBetween(today);
        }
        else{
            daysSinceLastActivity=0;
        }
        
        if (daysSinceLastActivity >= rule.DaysSinceLastActivity__c) {
            return rule.NewStatus__c;
        }
        return null;
    }

    /**
    * @description Check if not selected application should be updated 
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
        
        Integer daysSinceInterview = app.Last_Interview_Date__c.daysBetween(today);
        
        if (daysSinceInterview >= rule.DaysSinceInterview__c) {
            return rule.NewStatus__c;
        }
        return null;
    }

    /**
    * @description Check if withdrawn application should be updated
    * @author Akash Yadav | 08-03-2025 
    * @param app 
    * @param rule 
    * @return String 
    **/
    private String getWithdrawnStatus(Job_Application__c app, Candidate_Applicant_Metadata__mdt rule) {
        if (rule == null || 
            app.Candidate__r == null || 
            app.Candidate__r.Candidate_No_Longer_Interested__c != true) {
            return null;
        }
        return rule.NewStatus__c;
    }


    /**
    * @description 
    * @author Akash Yadav | 08-06-2025 
    * @param scheduleContext 
    **/
    global void execute(SchedulableContext scheduleContext){
        Database.executeBatch(new ApplicantStatusUpdateBatch(),200);
    }
}