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
    }

    @isTest
    static void testBatchUpdatesStatuses() {
        User adminUser = [SELECT Id FROM User WHERE Email = 'testadmin@example.com'];

        System.runAs(adminUser) {
            // Ensure metadata rules are deployed
            List<Candidate_Applicant_Metadata__mdt> rules = [SELECT Id,
                                                            RuleName__c, 
                                                            NewStatus__c, 
                                                            DaysSinceLastActivity__c, 
                                                            DaysSinceInterview__c, 
                                                            Active__c 
                FROM Candidate_Applicant_Metadata__mdt 
                WHERE RuleName__c IN (
                    'Inactive Applicant Rule', 
                    'Not Selected After Interview Rule', 
                    'Application Withdrawn Rule'
                )
                AND Active__c = TRUE
            ];
            System.assert(!rules.isEmpty(), 'Required metadata rules are missing.');

            Test.startTest();
            MonitorJobApllicationBatch batch = new MonitorJobApllicationBatch();
            Database.executeBatch(batch, 50);
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
            MonitorJobApllicationBatch batch = new MonitorJobApllicationBatch();
            Database.executeBatch(batch, 50);
            Test.stopTest();

            Job_Application__c result = [SELECT Status__c FROM Job_Application__c WHERE Id = :freshApp.Id];
            System.assertEquals('Inactive', result.Status__c, 'Fresh app should not have been updated');
        }
    }
}
