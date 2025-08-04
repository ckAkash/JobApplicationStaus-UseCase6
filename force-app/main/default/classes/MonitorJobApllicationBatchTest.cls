/**
 * @description       : Test class for MonitorJobApllicationBatch
 * @author            : Akash Yadav
 * @last modified on  : 08-04-2025
**/
@isTest
private class MonitorJobApllicationBatchTest {

    private static Id adminUserId;
    private static Id jobAppIdForInterview;

    @testSetup
    static void setupData() {
        // Create admin user
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'testadmin@example.com',
            Username = 'testadmin_' + DateTime.now().getTime() + '@example.com',
            Alias = 'tadmin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id
        );
        insert adminUser;
        adminUserId = adminUser.Id;

        // Create Job Application records
        // Inactive 
        Job_Application__c inactiveApp = new Job_Application__c(
            Status__c = 'Inactive',
            Last_Activity_Date__c = Date.today().addDays(-20)
        );

        // Withdrawn
        Job_Application__c withdrawnApp = new Job_Application__c(
            Status__c = 'Withdrawn',
            Candidate_No_Longer_Interested__c = true
        );

        // Not Selected (interview date via child record)
        Job_Application__c interviewApp = new Job_Application__c(
            Status__c = 'Not Selected'
        );

        insert new List<Job_Application__c>{ inactiveApp, withdrawnApp, interviewApp };
        jobAppIdForInterview = interviewApp.Id;

        //  Add interview detail child record
        Job_Interview_Detail__c interviewDetail = new Job_Interview_Detail__c(
            Job_Application__c = interviewApp.Id,
            Interview_Date__c = Date.today().addDays(-10)
        );
        insert interviewDetail;

        // Bulk record creation and insertion
        List<Job_Application__c> jobApplicationbulk = new List<Job_Application__c>();

        for (Integer iterator = 0; iterator < 99; iterator++) {

            //Inactive
            Job_Application__c inactiveApplication = new Job_Application__c(
            Status__c = 'Inactive',
            Last_Activity_Date__c = Date.today().addDays(-20)
            );

            // Withdrawn
            Job_Application__c withdrawnApplication = new Job_Application__c(
                Status__c = 'Withdrawn',
                Candidate_No_Longer_Interested__c = true
            );

            // Not Selected (interview date via child record)
            Job_Application__c interviewApplication = new Job_Application__c(
                Status__c = 'Not Selected'
            );

            jobApplicationbulk.add(inactiveApplication);
            jobApplicationbulk.add(withdrawnApplication);
            jobApplicationbulk.add(interviewApplication);
        }
        insert as user jobApplicationbulk;

        List<Job_Interview_Detail__c> interviewDetailList = new List<Job_Interview_Detail__c>();
        List<Job_Application__c> interviewJobAppList = [SELECT Id FROM Job_Application__c WHERE Status__c = 'Not Selected'];
        for(Job_Application__c jobApplication:interviewJobAppList){
            Job_Interview_Detail__c jobInterviewDetail = new Job_Interview_Detail__c(
                Job_Application__c = jobApplication.Id,
                Interview_Date__c = Date.today().addDays(-10)
            );
            interviewDetailList.add(jobInterviewDetail);
        }

        insert as user interviewDetailList;
        //bulkification of insertion done here
        
    }

    @isTest
    static void testBatchUpdatesStatuses() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        System.runAs(adminUser) {

            Test.startTest();
            MonitorJobApllicationBatch batchOne = new MonitorJobApllicationBatch();
            Database.executeBatch(batchOne, 50);
            Test.stopTest();

            // Query updated Job Applications
            List<Job_Application__c> apps = [SELECT Id,
                                                    Status__c, 
                                                    Candidate_No_Longer_Interested__c
                                            FROM Job_Application__c
                                            ORDER BY CreatedDate ASC
            ];

            System.assertEquals('Inactive', apps[0].Status__c, 'Inactive app not updated correctly');
            System.assertEquals('Withdrawn', apps[1].Status__c, 'Withdrawn app not updated correctly');
            System.assertEquals('Not Selected', apps[2].Status__c, 'Interview-based app not updated correctly');
        }
    }

    @isTest
    static void testNoUpdateWhenNotMatchingRule() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        // Fresh activity date: should not match inactive rule
        Job_Application__c freshApp = new Job_Application__c(
            Status__c = 'Inactive',
            Last_Activity_Date__c = Date.today()
        );
        insert freshApp;

        System.runAs(adminUser) {
            Test.startTest();
            MonitorJobApllicationBatch batchTwo = new MonitorJobApllicationBatch();
            Database.executeBatch(batchTwo, 50);
            Test.stopTest();

            Job_Application__c result = [SELECT Id,
                                                Status__c
                                         FROM Job_Application__c 
                                         WHERE Id = :freshApp.Id];
            System.assertEquals('Inactive', result.Status__c, 'Fresh app should not have been updated');
        }
    }

    @isTest
    static void testBatchUpdatesStatusesBulk(){
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        System.runAs(adminUser) {
             

            Test.startTest();
            MonitorJobApllicationBatch batchThree = new MonitorJobApllicationBatch();
            Database.executeBatch(batchThree, 50);
            Test.stopTest();
            
            // Query updated Job Applications
            List<Job_Application__c> apps = [SELECT Id,
                                                    Status__c, 
                                                    Candidate_No_Longer_Interested__c
                                            FROM Job_Application__c
                                            WHERE Status__c IN ('Withdrawn', 'Inactive', 'Not Selected')];
            Integer  countInactive = 0;
            Integer countWithdrawn = 0;
            Integer countNotSelected = 0;

            for (Job_Application__c app : apps) {
                if (app.Status__c == 'Inactive') {
                    countInactive++;
                } else if (app.Status__c == 'Withdrawn') {
                    countWithdrawn++;
                } else if (app.Status__c == 'Not Selected') {
                    countNotSelected++;
                }
            }

            System.Assert.areEqual(100, countInactive, 'Inactive count is incorrect');
            System.Assert.areEqual(100, countWithdrawn, 'Withdrawn count is incorrect');
            System.Assert.areEqual(100, countNotSelected, 'Not Selected count is incorrect');
        }
    }
}