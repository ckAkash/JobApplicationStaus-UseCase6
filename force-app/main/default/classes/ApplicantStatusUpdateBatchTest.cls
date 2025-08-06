/**
 * @description       : Test class for MonitorJobApplicationBatch - Fixed Version
 * @author            : Akash Yadav
 * @last modified on  : 08-06-2025
**/
@isTest
private class ApplicantStatusUpdateBatchTest {

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

        System.runAs(adminUser) {
            // First create Candidate records
            List<Candidate__c> testCandidates = new List<Candidate__c>();
            
            testCandidates.add(new Candidate__c(
                First_Name__c='Candidate',
                Last_Name__c='Lastname',
                Email__c = 'candidate1@test.com',
                Candidate_No_Longer_Interested__c = true
            )); // 0. Withdrawn Candidate
            
            testCandidates.add(new Candidate__c(
                First_Name__c='Candidate2',
                Last_Name__c='Lastname2',
                Email__c = 'candidate2@test.com'
            )); // 1. Inactive Candidate
            
            testCandidates.add(new Candidate__c(
                First_Name__c='Candidate3',
                Last_Name__c='Lastname3',
                Email__c = 'candidate3@test.com'
            )); // 2. not Selected Candidate
            
            testCandidates.add(new Candidate__c(
                First_Name__c='Candidate4',
                Last_Name__c='Lastname4',
                Email__c = 'candidate4@test.com'
            )); // 3. everything fine candidate
            
            
            insert testCandidates;

            // Create Job Application records with proper test data
            List<Job_Application__c> testApps = new List<Job_Application__c>();
            

            testApps.add(new Job_Application__c(
                Status__c = 'New', 
                Last_Activity_Date__c = Date.today(),
                Candidate__c = testCandidates[0].Id
            )); // 0. withdrawed Candidate's job application


            testApps.add(new Job_Application__c(
                Status__c = 'New',
                Last_Activity_Date__c = Date.today().addDays(-35),
                Candidate__c = testCandidates[1].Id 
            ));//1. Inactive Candidate's job application

            testApps.add(new Job_Application__c(
                Status__c = 'Interviewed',
                Last_Activity_Date__c = Date.today(),
                Candidate__c = testCandidates[2].Id
            )); //2.  not selected

            testApps.add(new Job_Application__c(
                Status__c = 'New',
                Last_Activity_Date__c = Date.today().addDays(-5), // Too recent
                Candidate__c = testCandidates[3].Id
            )); //3. Fresh active application

            insert testApps;

            // Create interview detail for Not Selected application
            Job_Interview_Detail__c interviewDetail = new Job_Interview_Detail__c(
                Interview_Date__c = Date.today().addDays(-20), // The status rule expect interview within the last 15 days of interview date
                Job_Application__c = testApps[2].Id
            );
            
            insert interviewDetail;
        }
    }

    @isTest
    static void testBatchProcessesCorrectly() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        System.runAs(adminUser) {


            Test.startTest();
            ApplicantStatusUpdateBatch batch = new ApplicantStatusUpdateBatch();
            Database.executeBatch(batch, 200);
            Test.stopTest();

            List<Job_Application__c> updatedApps = [SELECT Id,
                                                    Status__c, 
                                                    Last_Activity_Date__c, 
                                                    Last_Interview_Date__c,
                                                    Candidate__c, 
                                                    Candidate__r.Candidate_No_Longer_Interested__c,
                                                    Candidate__r.First_Name__c
                FROM Job_Application__c
                WHERE Candidate__r.First_Name__c LIKE 'Candidate%'
                ORDER By createdDate
            ];
            

            System.assertEquals('Withdrawn', updatedApps[0].Status__c, 'Status did not changed to Withdrawn');
            System.assertEquals('Inactive', updatedApps[1].Status__c, 'Status did not changed to Inactive');
            System.assertEquals('Not Selected', updatedApps[2].Status__c, 'Status did not changed to Not Selected');
            System.assertEquals('New', updatedApps[3].Status__c, 'Status Changed from new');
        }
    }


    @isTest
    static void testBatchWithNoMatchingRules() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        System.runAs(adminUser) {
            // Create candidates for no-match test
            List<Candidate__c> noMatchCandidates = new List<Candidate__c>();
            
            noMatchCandidates.add(new Candidate__c(
                First_Name__c='Firstname22',
                Last_Name__c='Lastname22',
                Email__c = 'nomatch1@test.com',
                Candidate_No_Longer_Interested__c = false
            ));
            
            noMatchCandidates.add(new Candidate__c(
                First_Name__c='Firstname21',
                Last_Name__c='Lastname21',
                Email__c = 'nomatch2@test.com'
            ));
            
            insert noMatchCandidates;

            // Create applications that shouldn't match any rules
            List<Job_Application__c> noMatchApps = new List<Job_Application__c>();
            
            noMatchApps.add(new Job_Application__c(
                Status__c = 'New',
                Candidate__c = noMatchCandidates[0].Id // Candidate has Candidate_No_Longer_Interested = false
            ));

            noMatchApps.add(new Job_Application__c(
                Status__c = 'New',
                Candidate__c = noMatchCandidates[1].Id
                // No interview date - won't trigger not selected rule
            ));

            insert noMatchApps;

            Test.startTest();
            ApplicantStatusUpdateBatch batch = new ApplicantStatusUpdateBatch();
            Database.executeBatch(batch, 200);
            Test.stopTest();

            // Verify no changes were made
            List<Job_Application__c> unchangedApps = [
                SELECT Id, Status__c
                FROM Job_Application__c
                WHERE Id IN :noMatchApps
            ];

            System.assertEquals('New', unchangedApps[0].Status__c, 'Withdrawn app without flag should remain unchanged');
            System.assertEquals('New', unchangedApps[1].Status__c, 'Not Selected app without interview should remain unchanged');
        }
    }
}